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
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculamos el límite exacto de hace 24 horas
    final DateTime limit24h = DateTime.now().subtract(
      const Duration(hours: 24),
    );

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
        final bool isPremium = userData?['subscription_status'] == 'premium';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: Text(
              isPremium ? "Historial Completo" : "Mi Glucosa (24h)",
              style: const TextStyle(fontWeight: FontWeight.bold),
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
                return const Center(child: Text("Error de conexión."));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;

              // LÓGICA DE FILTRADO 24 HORAS:
              // Si es Premium: Muestra todo.
              // Si es Gratis: Solo registros cuya fecha sea posterior a 'limit24h'.
              List<QueryDocumentSnapshot> logs = isPremium
                  ? allDocs
                  : allDocs.where((doc) {
                      final timestamp = doc['created_at'] as Timestamp?;
                      if (timestamp == null) return false;
                      return timestamp.toDate().isAfter(limit24h);
                    }).toList();

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
                      Text(
                        isPremium
                            ? "Tendencia General"
                            : "Tendencia (Últimas 24h)",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: logs.isEmpty
                            ? const Center(
                                child: Text("No hay datos en las últimas 24h"),
                              )
                            : _buildChart(logs.reversed.toList()),
                      ),

                      const SizedBox(height: 30),
                      if (!isPremium) _buildPremiumBanner(context),

                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // El Expanded obliga al texto a no pasarse del espacio disponible
                          Expanded(
                            child: Text(
                              isPremium
                                  ? "Historial de Registros"
                                  : "Registros Recientes (24h)",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow
                                  .ellipsis, // Si es muy largo, pone "..."
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ), // Un pequeño espacio de respiro
                          TextButton.icon(
                            onPressed: () => _generatePdfReport(
                              logs,
                              user.displayName ?? "Paciente",
                              isPremium,
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf,
                              size: 20,
                              color: Colors.red,
                            ),
                            label: Text(
                              isPremium ? "Exportar Todo" : "PDF Hoy",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final data =
                              logs[index].data() as Map<String, dynamic>;
                          return _buildLogTile(data);
                        },
                      ),

                      if (!isPremium && allDocs.length > logs.length)
                        _buildLockedHistoryInfo(), // El widget que dice que hay más datos bloqueados
                    ],
                  ),
                ),
              );
            },
          ),
          // EL BOTÓN DE AGREGAR SIEMPRE ESTÁ PRESENTE
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEntry(context),
            backgroundColor: Colors.blue.shade800,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildLockedHistoryInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20, bottom: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: Colors.blue.shade200,
            size: 40,
          ),
          const SizedBox(height: 15),
          const Text(
            "Historial antiguo bloqueado",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            "Solo puedes ver las últimas 24 horas. Para acceder a todo tu historial y descargar reportes, activa el Plan Premium.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: () => _showPremiumModal(context),
            child: Text(
              "SABER MÁS",
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
        // CONFIGURACIÓN DE INTERACCIÓN (TOOLTIP)
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blue.shade900,
            tooltipBorderRadius: BorderRadius.all(Radius.circular(12)),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.x.toInt();
                final data = logs[index].data() as Map<String, dynamic>;
                final int value = data['value'] ?? 0;
                final DateTime date = (data['created_at'] as Timestamp)
                    .toDate();

                return LineTooltipItem(
                  // Mostramos: "120 mg/dL \n Hoy - 08:30 AM \n Ayunas"
                  "$value mg/dL\n${_getRelativeDate(date)} - ${DateFormat('hh:mm a').format(date)}\n${data['timing']}",
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true, // Habilita que responda al toque
        ),
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
    DateTime date = DateTime.now();
    if (data['created_at'] != null) {
      date = (data['created_at'] as Timestamp).toDate();
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCritical ? Colors.red : Colors.black,
          ),
        ),
        subtitle: Text(
          // Aquí está la clave: "Hoy", "Ayer" o Fecha + Hora + Momento
          "${_getRelativeDate(date)} • ${DateFormat('hh:mm a').format(date)} - ${data['timing']}",
          style: const TextStyle(fontSize: 12),
        ),
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

  Future<void> _generatePdfReport(
    List<QueryDocumentSnapshot> logs,
    String patientName,
    bool isPremium,
  ) async {
    final pdf = pw.Document();
    final DateTime now = DateTime.now();
    final chartLogs = logs.reversed.toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Gluco Care ${isPremium ? 'Premium' : ''}",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(now),
                  style: const pw.TextStyle(color: PdfColors.grey),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text("Reporte Personal de Glucosa: $patientName"),
            pw.Divider(color: PdfColors.blue900, thickness: 1.5),
            pw.SizedBox(height: 20),

            // Gráfica (Solo útil si hay datos)
            if (logs.isNotEmpty) ...[
              pw.Text(
                "Gráfico de Tendencia",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 180,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis(
                      List.generate(chartLogs.length, (i) => i.toDouble()),
                      buildLabel: (i) => pw.Text(
                        _getRelativeDate(
                          (chartLogs[i.toInt()]['created_at'] as Timestamp)
                              .toDate(),
                        ),
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ),
                    yAxis: pw.FixedAxis(
                      [0, 50, 100, 150, 200, 250, 300],
                      buildLabel: (v) =>
                          pw.Text('$v', style: const pw.TextStyle(fontSize: 8)),
                    ),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      drawPoints: true,
                      pointSize: 3,
                      color: PdfColors.blue700,
                      data: List.generate(
                        chartLogs.length,
                        (i) => pw.PointChartValue(
                          i.toDouble(),
                          (chartLogs[i]['value'] as num).toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 30),

            // Tabla de Datos
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Momento', 'Valor (mg/dL)', 'Estado'],
              data: logs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final int val = data['value'] ?? 0;
                final DateTime date = (data['created_at'] as Timestamp)
                    .toDate();
                String status = val < 70
                    ? "Bajo"
                    : (val > 180
                          ? "Crítico"
                          : (val > 140 ? "Elevado" : "Normal"));
                return [
                  _getRelativeDate(date),
                  data['timing'] ?? 'N/A',
                  "$val",
                  status,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellAlignment: pw.Alignment.center,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey100, width: .5),
                ),
              ),
              cellDecoration: (index, data, rowNum) => rowNum % 2 == 0
                  ? const pw.BoxDecoration(color: PdfColors.grey100)
                  : const pw.BoxDecoration(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "Hoy";
    } else if (dateToCheck == yesterday) {
      return "Ayer";
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}
