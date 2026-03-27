import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/models/plan_config.dart';
import 'package:gluco_care_app/widgets/health_charts.dart';
import 'package:intl/intl.dart';
import 'add_entry_modal.dart';
import 'welcome_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () => _subscription.cancel(),
      onError: (error) => _showSnackBar("Error de conexión"),
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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final plan = PlanConfig.getSettings(
          userData?['subscription_status'] ?? 'free',
        );

        DateTime cutOffDate = DateTime.now().subtract(
          Duration(days: plan.historyDays),
        );
        Timestamp cutOffTimestamp = Timestamp.fromDate(cutOffDate);

        final bool isPremium = userData?['subscription_status'] == 'premium';

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF0F2F8),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.black,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola, ${userData?['full_name']?.split(' ')[0] ?? 'Paciente'}",
                  style: TextStyle(
                    fontSize: 19,
                    color: isDark ? Colors.blueAccent : Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Tu Resumen de Salud",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _generatedLinkingCode,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => FirebaseAuth.instance.signOut(),
                color: Colors.blue,
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('glucose_logs')
                .where('user_id', isEqualTo: user.uid)
                .where('created_at', isGreaterThanOrEqualTo: cutOffTimestamp)
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, glucoseSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('blood_pressure_logs')
                    .where('user_id', isEqualTo: user.uid)
                    .where(
                      'created_at',
                      isGreaterThanOrEqualTo: cutOffTimestamp,
                    )
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, pressureSnapshot) {
                  if (glucoseSnapshot.hasError) {
                    return Center(
                      child: SelectableText(
                        "ERROR GLUCOSA: ${glucoseSnapshot.error}",
                      ),
                    );
                  }
                  if (pressureSnapshot.hasError) {
                    return Center(
                      child: SelectableText(
                        "ERROR PRESIÓN: ${pressureSnapshot.error}",
                      ),
                    );
                  }
                  if (!glucoseSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<Map<String, dynamic>> allLogs = [];
                  for (var doc in glucoseSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['type'] = 'glucose';
                    data['id'] = doc.id;
                    allLogs.add(data);
                  }
                  if (pressureSnapshot.hasData &&
                      pressureSnapshot.data != null) {
                    for (var doc in pressureSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      data['type'] = 'pressure';
                      data['id'] = doc.id;
                      allLogs.add(data);
                    }
                  }
                  allLogs.sort(
                    (a, b) => (b['created_at'] as Timestamp).compareTo(
                      a['created_at'] as Timestamp,
                    ),
                  );

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSubscriptionBanner(
                            userData?['subscription_status'] ?? 'free',
                          ),
                          _buildQuickSummary(allLogs, isDark),
                          const SizedBox(height: 30),
                          HealthChart(allLogs: allLogs, isPremium: isPremium),
                          const SizedBox(height: 30),
                          _buildHistoryHeader(allLogs, user, isPremium),
                          const SizedBox(height: 10),
                          allLogs.isEmpty
                              ? _buildEmptyState(isDark)
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: allLogs.length,
                                  itemBuilder: (context, index) {
                                    final logData = allLogs[index];

                                    return Dismissible(
                                      key: Key(
                                        logData['id'] ?? index.toString(),
                                      ), // Firebase ID como llave
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 20,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_sweep,
                                          color: Colors.white,
                                        ),
                                      ),
                                      confirmDismiss: (direction) =>
                                          _confirmDelete(logData),
                                      child: InkWell(
                                        onLongPress: () => _showAddEntry(
                                          context,
                                          logData,
                                        ), // Toque largo para editar
                                        borderRadius: BorderRadius.circular(20),
                                        child: _buildUnifiedLogTile(logData),
                                      ),
                                    );
                                  },
                                ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntry(context),
            backgroundColor: const Color(0xFF1E2746),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Añadir",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.assignment_late_outlined,
              size: 80,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              "¡Empieza tu camino hoy!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Aún no tienes registros de salud.\nPresiona el botón '+' para añadir el primero.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSummary(List<Map<String, dynamic>> logs, bool isDark) {
    final lastGluc = logs.firstWhere(
      (l) => l['type'] == 'glucose',
      orElse: () => {},
    );
    final lastPress = logs.firstWhere(
      (l) => l['type'] == 'pressure',
      orElse: () => {},
    );

    return Row(
      children: [
        _summaryCard(
          "Glucosa",
          lastGluc['value']?.toString() ?? "--",
          "mg/dL",
          Icons.water_drop,
          Colors.blue,
          isDark,
        ),
        const SizedBox(width: 15),
        _summaryCard(
          "Presión",
          lastPress['systolic'] != null
              ? "${lastPress['systolic']}/${lastPress['diastolic']}"
              : "--",
          "mmHg",
          Icons.favorite,
          Colors.redAccent,
          isDark,
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 15),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "$title ($unit)",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(
    List<Map<String, dynamic>> allLogs,
    User user,
    bool isPremium,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Usamos el StreamBuilder para conocer el estado real de la suscripción del usuario
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final String status = userData?['subscription_status'] ?? 'free';

        // El acceso al PDF solo se activa si NO es 'free'
        final bool hasPdfAccess = status != 'free';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Historial Médico",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: hasPdfAccess
                  ? () => _generatePdfReport(
                      allLogs,
                      user.displayName ?? "Paciente",
                      status == 'premium',
                    )
                  : () {
                      // --- CAMBIO AQUÍ: Solo mostramos el mensaje, eliminamos el modal ---
                      _showSnackBar("Función disponible en el Plan Ideal");
                    },
              icon: Icon(
                Icons.picture_as_pdf_rounded,
                color: hasPdfAccess
                    ? Colors.redAccent
                    : Colors.grey.withOpacity(0.5),
                size: 18,
              ),
              label: Text(
                "PDF",
                style: TextStyle(
                  color: hasPdfAccess
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.grey.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnifiedLogTile(Map<String, dynamic> data) {
    final bool isGluc = data['type'] == 'glucose';
    final DateTime date = (data['created_at'] as Timestamp).toDate();
    final bool isHigh = data['is_high_risk'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHigh
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isGluc ? Colors.blue : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isGluc ? Icons.bloodtype_outlined : Icons.favorite_outline,
              color: isGluc ? Colors.blue : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGluc
                      ? "${data['value']} mg/dL"
                      : "${data['systolic']}/${data['diastolic']} mmHg",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('hh:mm a • d MMM').format(date),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isHigh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "ALERTA",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- MÉTODOS DE APOYO (Mantener igual que antes) ---
  void _showAddEntry(
    BuildContext context, [
    Map<String, dynamic>? initialData,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        // Pasamos los datos iniciales al modal
        child: AddEntryModal(initialData: initialData),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) return "Hoy";
    if (date.day == now.day - 1) return "Ayer";
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Los métodos _listenToPurchaseUpdated, _startPurchaseFlow, _updateUserToPremium, _generatedLinkingCode, _generatePdfReport, _showCodeDialog, _showPremiumModal y _buildFeatureRow se mantienen igual para no perder funcionalidad.
  // ... (Código anterior de esos métodos)
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
          await _updateUserSubscription(purchaseDetails.productID);
          _showSnackBar("¡Felicidades! Ya eres Premium.");
        }

        // Siempre hay que finalizar la compra para que Google no devuelva el dinero
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<void> _startPurchaseFlow(String planType) async {
    debugPrint(
      "Ingreso a la funcion _startPurchaseFlow con el planType: $planType",
    );
    setState(() {
      _isLoading = true;
    });

    // 1. Verificar si la tienda está disponible
    final bool available = await _inAppPurchase.isAvailable();

    if (!available) {
      _showSnackBar("La tienda de Google Play no está disponible.");
      return;
    }

    String productId;
    switch (planType) {
      case 'basic':
        productId = 'glucocare_basic_new';
        break;
      case 'ideal':
        productId = 'glucocare_ideal_new';
        break;
      case 'premium':
        productId = 'glucocare_premium_new';
        break;
      default:
        productId = 'glucocare_premium_monthly';
    }

    // 2. Definir el ID del producto que creaste en Google Play Console
    final Set<String> _kIds = {productId};

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

  Future<void> _updateUserSubscription(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String finalStatus = 'free';

    // Lógica para asignar el plan correcto basado en el ID de Google Play
    if (productId == 'glucocare_basic_new') {
      finalStatus = 'basic';
    } else if (productId == 'glucocare_ideal_new') {
      finalStatus = 'ideal';
    } else if (productId == 'glucocare_premium_new') {
      finalStatus = 'premium';
    } else if (productId == 'glucocare_premium_monthly') {
      // ESTE ES EL CASO DE TU MAMÁ: El ID viejo ahora da beneficios Premium
      finalStatus = 'premium';
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'subscription_status': finalStatus,
      'last_purchase_date': FieldValue.serverTimestamp(),
      'active_product_id': productId,
    });

    setState(() {}); // Refresca el Dashboard para que el banner desaparezca
  }

  Future<bool?> _confirmDelete(Map<String, dynamic> data) async {
    // EXTRAER EL ID CORRECTO:
    // En Firestore, el ID del documento es la "llave" para borrar.
    final String? docId = data['id'];
    final String collection = data['type'] == 'glucose'
        ? 'glucose_logs'
        : 'blood_pressure_logs';

    if (docId == null) {
      _showSnackBar("Error: No se encontró el ID del registro");
      return false;
    }

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Borrar registro?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final collection = data['type'] == 'glucose'
                  ? 'glucose_logs'
                  : 'blood_pressure_logs';

              await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(data['id']) // Asegúrate de que el ID esté en el map
                  .delete();

              Navigator.pop(context, true);
              _showSnackBar("Registro eliminado");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "BORRAR",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _generatePdfReport(
    List<Map<String, dynamic>> allLogs, // Ahora recibe la lista combinada
    String patientName,
    bool isPremium,
  ) async {
    final pdf = pw.Document();
    final DateTime now = DateTime.now();

    // Separar logs para las tablas
    final glucoseLogs = allLogs.where((l) => l['type'] == 'glucose').toList();
    final pressureLogs = allLogs.where((l) => l['type'] == 'pressure').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "My Health Log - Reporte Médico",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(DateFormat('dd/MM/yyyy').format(now)),
          ],
        ),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text("Paciente: $patientName")),

            // SECCIÓN 1: GLUCOSA
            if (glucoseLogs.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                "1. Registro de Glucosa Capilar",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Momento', 'Valor', 'Riesgo'],
                data: glucoseLogs
                    .map(
                      (l) => [
                        _getRelativeDate(
                          (l['created_at'] as Timestamp).toDate(),
                        ),
                        l['timing'] ?? '-',
                        "${l['value']} mg/dL",
                        (l['is_high_risk'] ?? false) ? "ELEVADO" : "NORMAL",
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
              ),
            ],

            // SECCIÓN 2: PRESIÓN ARTERIAL (El nuevo valor agregado)
            if (pressureLogs.isNotEmpty) ...[
              pw.SizedBox(height: 40),
              pw.Text(
                "2. Registro de Presión Arterial y Pulso",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Presión (Sis/Dia)', 'Pulso', 'Estado'],
                data: pressureLogs
                    .map(
                      (l) => [
                        _getRelativeDate(
                          (l['created_at'] as Timestamp).toDate(),
                        ),
                        "${l['systolic']}/${l['diastolic']} mmHg",
                        "${l['pulse']} LPM",
                        (l['is_high_risk'] ?? false)
                            ? "HIPERTENSIÓN"
                            : "NORMAL",
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.red700,
                ),
              ),
            ],

            if (glucoseLogs.isEmpty && pressureLogs.isEmpty)
              pw.Center(
                child: pw.Text(
                  "No hay registros para mostrar en este periodo.",
                ),
              ),

            pw.SizedBox(height: 50),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                "Este reporte es informativo. No sustituye el diagnóstico de un profesional de la salud.",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showPremiumModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que quepa todo el contenido
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.verified_user_rounded,
                size: 50,
                color: Colors.blue,
              ),
              const SizedBox(height: 10),
              const Text(
                "Elige tu Plan de Cuidado",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Protege tu salud y la de tu familia",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 25),

              // --- PLAN BÁSICO ---
              _buildPlanCard(
                title: "Plan Básico",
                price: "4.99",
                description: "30 días de historial • 2 Cuidadores",
                icon: Icons.person_outline,
                color: Colors.blueGrey,
                onTap: () => _startPurchaseFlow('basic'),
              ),

              // --- PLAN IDEAL (DESTACADO) ---
              _buildPlanCard(
                title: "Plan Ideal",
                price: "9.99",
                description: "90 días (3 meses) • 3 Cuidadores • PDF Pro",
                icon: Icons.family_restroom,
                color: Colors.blue,
                isBestSeller: true,
                onTap: () => _startPurchaseFlow('ideal'),
              ),

              // --- PLAN PREMIUM ---
              _buildPlanCard(
                title: "Plan Premium",
                price: "14.99",
                description: "Historial Ilimitado • Cuidadores Ilimitados",
                icon: Icons.all_inclusive,
                color: const Color(0xFF1E2746),
                onTap: () => _startPurchaseFlow('premium'),
              ),

              const SizedBox(height: 20),
              const Text(
                "Pagos seguros procesados por Google Play Store",
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para las tarjetas de planes
  Widget _buildPlanCard({
    required String title,
    required String price,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isBestSeller = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isBestSeller
              ? color.withValues(alpha: 0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBestSeller ? color : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.grey.shade200 : color, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isBestSeller)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "RECOMENDADO",
                            style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              "\$$price",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blueAccent : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner(String currentStatus) {
    if (currentStatus != 'free') {
      return const SizedBox.shrink(); // No mostrar si ya paga
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Modo Gratuito (3 días)",
                  style: TextStyle(
                    color: Theme.of(context).cardColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "Tus registros anteriores están ocultos. ¡Asegura tu historial!",
                  style: TextStyle(
                    color: Theme.of(context).cardColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                _showPremiumModal(context), // Reutilizamos tu modal de pago
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "SUBIR",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
