import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'add_entry_modal.dart';
import 'welcome_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isLoading = false;

  // Escuchador de cambios de autenticación
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    // Escuchamos los cambios en las compras
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        _showSnackBar("Error de conexión con la tienda");
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _checkAuthStatus() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        // Si la sesión expira (como te pasó tras 4h), volvemos al inicio
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Si por alguna razón el widget se construye y no hay user, evitamos el crash
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Mi Glucosa (24h)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _generatedLinkingCode,
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.blue,
            ),
            tooltip: "Vincular con familiar",
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('glucose_logs')
            .where('user_id', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error de conexión. Reintenta."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<QueryDocumentSnapshot> logs = snapshot.data?.docs ?? [];

          // Ordenar: Más reciente primero
          logs.sort((a, b) {
            Timestamp t1 = a['created_at'] ?? Timestamp.now();
            Timestamp t2 = b['created_at'] ?? Timestamp.now();
            return t2.compareTo(t1);
          });

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tendencia del día",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: logs.isEmpty
                        ? const Center(child: Text("No hay datos registrados"))
                        : _buildChart(logs.reversed.toList()),
                  ),
                  const SizedBox(height: 30),

                  // Botón Premium
                  _buildPremiumBanner(context),

                  const SizedBox(height: 30),
                  const Text(
                    "Registros Recientes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final data = logs[index].data() as Map<String, dynamic>;
                      return _buildLogTile(data);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntry(context),
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _startPurchaseFlow() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Verificar si la tienda está disponible
    final bool available = await _inAppPurchase.isAvailable();

    if (!available) {
      _showSnackBar("La tienda de Google Play no está disponible.");
      return;
    }

    // 2. Definir el ID del producto que creaste en Google Play Console
    const Set<String> _kIds = {'glucocare_premium_monthly'};

    // 3. Cargar los detalles del producto desde los servidores de Google
    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails(_kIds);

    if (response.notFoundIDs.isNotEmpty) {
      _showSnackBar("No se encontró el producto premium.");
      return;
    }

    // 4. Lanzar la compra
    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    // Esto abre la ventanita nativa de Google Pay
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

    setState(() {
      _isLoading = false;
    });
  }

  // --- WIDGETS AUXILIARES MEJORADOS ---

  Widget _buildPremiumBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            "¿Quieres ver más de 24 horas?",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          TextButton.icon(
            onPressed: () => _showPremiumModal(context),
            icon: const Icon(Icons.star, color: Colors.amber, size: 20),
            label: const Text("Pásate a Premium"),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<QueryDocumentSnapshot> logs) {
    List<FlSpot> spots = [];
    for (int i = 0; i < logs.length; i++) {
      double val = (logs[i]['value'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue.shade700,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade700.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> data) {
    String formattedTime = "---";
    if (data['created_at'] != null) {
      DateTime date = (data['created_at'] as Timestamp).toDate();
      formattedTime = DateFormat('hh:mm a').format(date);
    }

    final int value = data['value'] ?? 0;
    final bool isCritical = value > 180 || value < 70;

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCritical ? Colors.red.shade50 : Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.bloodtype,
            color: isCritical ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          "$value mg/dL",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$formattedTime - ${data['timing']}"),
        trailing: const Icon(Icons.chevron_right, size: 16),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // Modales se mantienen igual pero asegúrate de que el context sea válido
  void _showPremiumModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, size: 60, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "Plan Premium Gluco Care",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildFeatureRow(Icons.history, "Historial ilimitado (más de 24h)"),
            _buildFeatureRow(
              Icons.picture_as_pdf,
              "Reportes PDF para tu doctor",
            ),
            _buildFeatureRow(Icons.share, "Envío completo por WhatsApp"),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                _startPurchaseFlow();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "SUSCRIBIRME POR \$4.99 / MES",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Pago procesado de forma segura por Google Play",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEntry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Quitamos el transparent de aquí para que el fondo sea el por defecto (blanco/gris)
      // O lo mantenemos pero aseguramos que el modal tenga estilo:
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.white, // <--- Forzamos el color blanco aquí
      builder: (context) => const AddEntryModal(),
    );
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Mostrar un indicador de carga si quieres
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _showSnackBar("Error en el pago: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // ¡ÉXITO! Actualizamos Firestore
          await _updateUserToPremium();
          _showSnackBar("¡Felicidades! Ya eres Premium.");
        }

        // Siempre hay que finalizar la compra para que Google no devuelva el dinero
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating, // Para que se vea más moderno
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateUserToPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'subscription_status': 'premium'},
      );
    }
  }

  Future<void> _generatedLinkingCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Generar código de 6 caracteres
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(Random().nextInt(chars.length)),
      ),
    );

    try {
      // 2. Guardar en la colección global de conexiones
      await FirebaseFirestore.instance.collection('connections').doc(code).set({
        'patientId': user.uid,
        'patientName': user.displayName ?? 'Familiar',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(
          const Duration(hours: 1),
        ), // El código expira en 1h
      });

      // 3. Mostrar el código en un Dialog
      _showCodeDialog(code);
    } catch (e) {
      debugPrint("Error al generar codigo: $e");
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Código de Vinculación", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Dicta este código a tu familiar:"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Este código expirará en 1 hora",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
