import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/screens/welcome_screen.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  bool _isSaving = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        _showSnackBar("Error en la tienda: $error", Colors.red);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);

    return StreamBuilder<DocumentSnapshot>(
      // ESCUCHA 1: Tu perfil de usuario (Cuidador)
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String? linkedId = userData?['linkedPatientId'];
        final String? linkedName =
            userData?['linkedPatientName'] ?? "Mi Paciente";
        // Determinamos si es Premium desde el perfil del cuidador
        final bool isPremiumUser =
            userData?['subscription_status'] == 'premium';

        // SI NO HAY VÍNCULO: Mostramos pantalla de bienvenida
        if (linkedId == null) {
          return _buildEmptyState();
        }

        // SI HAY VÍNCULO: Mostramos el Dashboard Pro
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Monitoreando a:",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  linkedName ?? "Familiar",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            // ESCUCHA 2: Registros de glucosa del paciente vinculado
            stream: FirebaseFirestore.instance
                .collection('glucose_logs')
                .where('user_id', isEqualTo: linkedId)
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Center(child: Text("Error al cargar datos"));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final allLogs = snapshot.data!.docs;

              // FILTRO DE NEGOCIO:
              // Si es Premium: Ve todo.
              // Si es Gratis: Solo ve registros desde las 00:00 de hoy.
              final logs = isPremiumUser
                  ? allLogs
                  : allLogs.where((doc) {
                      final timestamp = doc['created_at'] as Timestamp?;
                      if (timestamp == null) return false;
                      return timestamp.toDate().isAfter(startOfToday);
                    }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (!isPremiumUser) ...[
                            _buildPremiumBanner(isPremiumUser),
                            const SizedBox(height: 20),
                          ],
                          _buildStatusHero(logs),
                          const SizedBox(height: 25),
                          _buildSectionHeader(
                            "Alertas de Riesgo",
                            Icons.warning_amber_rounded,
                          ),
                          // Mostramos alertas de los registros que el usuario puede ver
                          ...logs
                              .where((doc) {
                                final val = doc['value'] as int;
                                return val > 180 || val < 70;
                              })
                              .map(
                                (doc) => _buildProfessionalAlertTile(
                                  doc.data() as Map<String, dynamic>,
                                ),
                              ),
                          const SizedBox(height: 25),
                          _buildSectionHeader("Registros de Hoy", Icons.today),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _generatePdfReport(
                                logs,
                                linkedName ?? "Paciente",
                                isPremiumUser,
                              ),
                              icon: const Icon(
                                Icons.picture_as_pdf,
                                size: 18,
                                color: Colors.red,
                              ),
                              label: Text(
                                isPremiumUser
                                    ? "Exportar Reporte Completo"
                                    : "Reporte de Hoy (PDF)",
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildSimpleLogTile(
                        logs[index].data() as Map<String, dynamic>,
                      ),
                      childCount: logs.length,
                    ),
                  ),
                  // Si hay registros antiguos ocultos, mostramos el aviso de bloqueo
                  if (!isPremiumUser &&
                      allLogs.any(
                        (doc) => (doc['created_at'] as Timestamp)
                            .toDate()
                            .isBefore(startOfToday),
                      ))
                    SliverToBoxAdapter(child: _buildLockedHistoryInfo()),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalAlertTile(Map<String, dynamic> data) {
    final int value = data['value'] ?? 0;
    final DateTime date =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.red[100],
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Alerta: $value mg/dL",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  "${_getRelativeDate(date)} • ${data['timing']} • ${DateFormat('hh:mm a').format(date)}",
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSimpleLogTile(Map<String, dynamic> data) {
    final int value = data['value'] ?? 0;
    final DateTime date =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

    final bool isCritical = value < 70 || value > 180;
    final bool isOk = value >= 70 && value <= 140;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 5,
          height: 40,
          decoration: BoxDecoration(
            color: isCritical
                ? Colors.red
                : (isOk ? Colors.green : Colors.orange),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          "$value mg/dL",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCritical
                ? Colors.red
                : Colors.black, // Color rojo si es crítico
          ),
        ),
        subtitle: Text(
          // Agregamos la fecha relativa aquí también
          "${_getRelativeDate(date)} • ${data['timing']} • ${DateFormat('hh:mm a').format(date)}",
        ),
        trailing: Icon(
          isCritical ? Icons.warning_rounded : Icons.circle,
          size: 14,
          color: isCritical
              ? Colors.red
              : (isOk ? Colors.green[200] : Colors.orange[200]),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Configuración de Monitoreo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: const Text("Desvincular Paciente"),
              onTap: () {
                Navigator.pop(context);
                _confirmUnlink();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Cerrar Sesión"),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // El StreamBuilder detectará que el usuario es nulo y podrías manejarlo ahí,
      // pero forzamos la salida para mayor seguridad.
      if (mounted) {
        // Reemplaza 'WelcomeScreen' por el nombre exacto de tu clase de inicio
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("Error al cerrar sesión: $e", Colors.red);
    }
  }

  Widget _buildStatusHero(List<QueryDocumentSnapshot> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();

    final lastValue = logs.first['value'] as int;
    final bool isOk = lastValue >= 70 && lastValue <= 140;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Última medición",
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    "$lastValue mg/dL",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOk ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOk ? "ESTABLE" : "REVISAR",
                  style: TextStyle(
                    color: isOk ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          const Text(
            "La constancia en el registro es clave para un buen control médico.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE VINCULACIÓN ---

  Future<void> _linkPatient(String code) async {
    setState(() => _isSaving = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('connections')
          .doc(code)
          .get();

      if (doc.exists) {
        String patientId = doc['patientId'];
        String patientName = doc['patientName'];

        final currentUser = FirebaseAuth.instance.currentUser;

        // Al actualizar Firestore, el StreamBuilder del build() detectará el cambio automáticamente
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({
              'linkedPatientId': patientId,
              'linkedPatientName': patientName,
            });

        _showSnackBar("¡Vinculación exitosa!", Colors.green);
      } else {
        _showSnackBar(
          "Código no encontrado. Verifica con tu familiar.",
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- MÉTODOS DE UI ---

  Widget _buildEmptyState() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.family_restroom, size: 100, color: Colors.blue[200]),
              const SizedBox(height: 20),
              const Text(
                "Aún no tienes a nadie vinculado",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Pide el código de vinculación a tu familiar para empezar el monitoreo.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              _isSaving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () => _showLinkCodeDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("INGRESAR CÓDIGO"),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Vincular Familiar"),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: "Ej: ABC123",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _linkPatient(codeController.text.trim().toUpperCase());
            },
            child: const Text("Vincular"),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(bool isPremiumUser) {
    if (isPremiumUser) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Desbloquea el historial",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Accede a más de 24 horas de datos.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _buyPremium(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("PREMIUM"),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSummaryCard(List<QueryDocumentSnapshot> logs) {
    if (logs.isEmpty) {
      return const Card(
        child: ListTile(title: Text("Sin registros en las últimas 24h")),
      );
    }
    double avg =
        logs.map((doc) => (doc['value'] as int)).reduce((a, b) => a + b) /
        logs.length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                "Mi Paciente (Mamá)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Estado en tiempo real"),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Promedio", "${avg.toStringAsFixed(0)}"),
                _buildStat("Registros", "${logs.length}"),
                _buildStat(
                  "Nivel",
                  avg > 150 ? "Alto" : "Normal",
                  color: avg > 150 ? Colors.orange : Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> data) {
    final DateTime date =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.red[50],
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: Text(
          "Glucosa Alta: ${data['value']} mg/dL",
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "${data['timing']} • ${DateFormat('hh:mm a').format(date)}",
        ),
      ),
    );
  }

  Widget _buildLockedHistoryInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_person_rounded, color: Colors.grey[400], size: 50),
          const SizedBox(height: 10),
          const Text(
            "Días anteriores bloqueados",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const Text(
            "Suscríbete por \$4.99 para ver todo el historial.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
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

  Future<void> _generatePdfReport(
    List<QueryDocumentSnapshot> logs,
    String patientName,
    bool isPremium,
  ) async {
    final pdf = pw.Document();
    final DateTime now = DateTime.now();

    // Invertimos para que el reporte sea cronológico (de más antiguo a más reciente)
    final chartLogs = logs.reversed.toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Encabezado
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
            pw.Text("Reporte de Monitoreo: $patientName"),
            pw.Divider(color: PdfColors.blue900, thickness: 1.5),
            pw.SizedBox(height: 20),

            // --- SECCIÓN DE LA GRÁFICA ---
            pw.Text(
              "Gráfico de Tendencia (Glucosa)",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              height: 180,
              child: pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis(
                    // Definimos las posiciones de los puntos en el eje X
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
                    [0, 50, 100, 150, 200, 250, 300], // Valores fijos del eje Y
                    buildLabel: (v) =>
                        pw.Text('$v', style: const pw.TextStyle(fontSize: 8)),
                  ),
                ),
                datasets: [
                  pw.LineDataSet(
                    drawPoints: true,
                    pointSize: 3,
                    color: PdfColors.blue700,
                    data: List.generate(chartLogs.length, (i) {
                      final val = (chartLogs[i]['value'] as num).toDouble();
                      return pw.PointChartValue(i.toDouble(), val);
                    }),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- TABLA DE REGISTROS ---
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Momento', 'Valor (mg/dL)', 'Estado'],
              data: logs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final int val = data['value'] ?? 0;
                final DateTime date = (data['created_at'] as Timestamp)
                    .toDate();

                String status = "Normal";
                if (val < 70)
                  status = "Bajo";
                else if (val > 180)
                  status = "Crítico";
                else if (val > 140)
                  status = "Elevado";

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

            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                "Este reporte es generado automáticamente por Gluco Care y es estrictamente informativo.",
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey,
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Abrir la interfaz nativa para imprimir o compartir
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _confirmUnlink() async {
    // Mostramos la alerta de confirmación
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Desvincular familiar?"),
        content: const Text(
          "Si desvinculas a tu familiar, dejarás de recibir sus actualizaciones de glucosa en tiempo real.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("SÍ, DESVINCULAR"),
          ),
        ],
      ),
    );

    // Si el usuario confirmó, procedemos a borrar los datos en Firestore
    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
                'linkedPatientId':
                    FieldValue.delete(), // Borra el campo por completo
                'linkedPatientName': FieldValue.delete(),
              });

          _showSnackBar("Familiar desvinculado correctamente", Colors.blueGrey);
        }
      } catch (e) {
        _showSnackBar("Error al desvincular: $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _showSnackBar("Procesando pago...", Colors.blue);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _showSnackBar(
            "Error al procesar: ${purchaseDetails.error}",
            Colors.red,
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // ¡PAGO EXITOSO! Actualizamos Firestore
          await _setPremiumStatus();

          _showSnackBar(
            "¡Bienvenido a Premium! Historial desbloqueado.",
            Colors.green,
          );
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<void> _setPremiumStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'subscription_status': 'premium'});
    }
  }

  Future<void> _buyPremium() async {
    const String premiumId =
        'gluco_care_premium_499'; // El ID que crees en Play Store / App Store
    final bool available = await InAppPurchase.instance.isAvailable();

    if (!available) {
      _showSnackBar("La tienda no está disponible", Colors.red);
      return;
    }

    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails({premiumId});

    if (response.notFoundIDs.isNotEmpty) {
      _showSnackBar("Producto no encontrado en la tienda", Colors.red);
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }
}
