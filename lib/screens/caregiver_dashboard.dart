import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/models/plan_config.dart';
import 'package:gluco_care_app/screens/welcome_screen.dart';
import 'package:gluco_care_app/widgets/health_charts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // NUEVO LÍMITE: 48 Horas para usuarios gratuitos
    final DateTime limit48h = DateTime.now().subtract(
      const Duration(hours: 48),
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

        final String? linkedId = userData?['linkedPatientId'];
        final String? linkedName = userData?['linkedPatientName'] ?? "Familiar";

        if (linkedId == null) return _buildEmptyState();

        // ESCUCHA AL PACIENTE PARA VER SU SUSCRIPCIÓN
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(linkedId)
              .snapshots(),
          builder: (context, patientProfileSnapshot) {
            if (!patientProfileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final patientProfile =
                patientProfileSnapshot.data!.data() as Map<String, dynamic>;

            final patientPlan = PlanConfig.getSettings(
              patientProfile['subscription_status'] ?? 'free',
            );
            DateTime patientCutOffDate = DateTime.now().subtract(
              Duration(days: patientPlan.historyDays),
            );
            Timestamp patientCutOffTimestamp = Timestamp.fromDate(
              patientCutOffDate,
            );

            // El cuidador es "Premium" si su PACIENTE es Premium
            final bool isPremiumAccess =
                patientProfile['subscription_status'] == 'premium';
            final bool isDark = Theme.of(context).brightness == Brightness.dark;

            return Scaffold(
              backgroundColor: isDark
                  ? const Color(0xFF121212)
                  : const Color(0xFFF0F2F8),
              appBar: _buildAppBar(linkedName, isDark),
              body: _buildPatientDataStream(
                linkedId,
                isPremiumAccess,
                patientCutOffTimestamp,
                linkedName,
                isDark,
              ),
            );
          },
        );
      },
    );
  }

  // --- ESCUCHA DE DATOS COMBINADOS ---
  Widget _buildPatientDataStream(
    String linkedId,
    bool isPremium,
    Timestamp cutOff,
    String? name,
    bool isDark,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('glucose_logs')
          .where('user_id', isEqualTo: linkedId)
          .where('created_at', isGreaterThanOrEqualTo: cutOff)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, glucSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('blood_pressure_logs')
              .where('user_id', isEqualTo: linkedId)
              .where('created_at', isGreaterThanOrEqualTo: cutOff)
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, pressSnapshot) {
            if (!glucSnapshot.hasData || !pressSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Combinar registros
            List<Map<String, dynamic>> allLogs = [];

            for (var doc in glucSnapshot.data!.docs) {
              var d = doc.data() as Map<String, dynamic>;
              d['type'] = 'glucose';
              allLogs.add(d);
            }

            for (var doc in pressSnapshot.data!.docs) {
              var d = doc.data() as Map<String, dynamic>;
              d['type'] = 'pressure';
              allLogs.add(d);
            }

            allLogs.sort(
              (a, b) => (b['created_at'] as Timestamp).compareTo(
                a['created_at'] as Timestamp,
              ),
            );

            // Aplicar filtro de 48 horas si no es Premium
            List<Map<String, dynamic>> visibleLogs = List.from(allLogs);

            visibleLogs.sort(
              (a, b) => (b['created_at'] as Timestamp).compareTo(
                a['created_at'] as Timestamp,
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickSummary(visibleLogs, isDark),
                  const SizedBox(height: 30),
                  HealthChart(allLogs: allLogs, isPremium: isPremium),
                  const SizedBox(height: 30),
                  _buildHistoryHeader(visibleLogs, name, isPremium, isPremium),
                  const SizedBox(height: 15),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleLogs.length,
                    itemBuilder: (context, index) =>
                        _buildUnifiedLogTile(visibleLogs[index], isDark),
                  ),
                  if (!isPremium && allLogs.length > visibleLogs.length)
                    _buildLockedHistoryInfo(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGETS REDISEÑADOS (Estilo Pro) ---

  AppBar _buildAppBar(String? name, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : Colors.black,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cuidando a:",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            name ?? "Familiar",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _showSettings(context),
        ),
      ],
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
          "Última Glucosa",
          lastGluc['value']?.toString() ?? "--",
          "mg/dL",
          Colors.blue,
          isDark,
        ),
        const SizedBox(width: 15),
        _summaryCard(
          "Última Presión",
          lastPress['systolic'] != null
              ? "${lastPress['systolic']}/${lastPress['diastolic']}"
              : "--",
          "mmHg",
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
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedLogTile(Map<String, dynamic> data, bool isDark) {
    final bool isGluc = data['type'] == 'glucose';
    final DateTime date = (data['created_at'] as Timestamp).toDate();
    final bool isHigh = data['is_high_risk'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(
          isGluc ? Icons.bloodtype : Icons.favorite,
          color: isGluc ? Colors.blue : Colors.red,
        ),
        title: Text(
          isGluc
              ? "${data['value']} mg/dL"
              : "${data['systolic']}/${data['diastolic']} mmHg",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isHigh ? Colors.red : (isDark ? Colors.white : Colors.black),
          ),
        ),
        subtitle: Text(
          "${_getRelativeDate(date)} • ${DateFormat('hh:mm a').format(date)}",
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: isHigh
            ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
            : null,
      ),
    );
  }

  Widget _buildHistoryHeader(
    List<Map<String, dynamic>> logs,
    String? name,
    bool isPremium,
    bool canExportPDF,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isPremium ? "Historial Completo" : "Historial Limitado",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        // BOTÓN DE PDF DINÁMICO
        TextButton.icon(
          onPressed: canExportPDF
              ? () => _generatePdfReport(logs, name ?? "Paciente", isPremium)
              : () {
                  _showSnackBar(
                    "Función disponible en el Plan Ideal de tu familiar",
                    Colors.orange,
                  );
                },
          icon: Icon(
            Icons.picture_as_pdf,
            size: 18,
            // Rojo si puede, Gris si no
            color: canExportPDF
                ? Colors.redAccent
                : Colors.grey.withOpacity(0.5),
          ),
          label: Text(
            "PDF",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              // Texto tenue si está desactivado
              color: canExportPDF
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.grey.withOpacity(0.5),
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedHistoryInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          Icon(Icons.lock_outline, color: Colors.blue),
          SizedBox(height: 10),
          Text(
            "Registros anteriores ocultos",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            "Dile a tu familiar que se pase a Premium para ver todo su historial.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS DE APOYO ---

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.link_off, color: Colors.red),
            title: const Text("Desvincular Familiar"),
            onTap: () {
              Navigator.pop(context); // Cierra el modal antes
              _confirmUnlink();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Cerrar Sesión"),
            onTap: () async {
              Navigator.pop(context); // 1. CERRAMOS EL MODAL PRIMERO
              await FirebaseAuth.instance.signOut(); // 2. CERRAMOS SESIÓN

              // 3. OPCIONAL: Redirección manual por si el StreamBuilder tarda
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) return "Hoy";
    if (date.day == now.day - 1) return "Ayer";
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // (Implementar aquí los métodos _confirmUnlink, _generatePdfReport y _buildEmptyState similares al código anterior)
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

  Future<void> _generatePdfReport(
    List<Map<String, dynamic>> allLogs,
    String patientName,
    bool isPremium,
  ) async {
    final pdf = pw.Document();
    final DateTime now = DateTime.now();

    // SEPARAMOS CON SEGURIDAD
    final glucoseLogs = allLogs.where((l) => l['type'] == 'glucose').toList();
    final pressureLogs = allLogs.where((l) => l['type'] == 'pressure').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, child: pw.Text("Reporte Médico: $patientName")),

            if (glucoseLogs.isNotEmpty) ...[
              pw.Text(
                "Glucosa",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Valor', 'Momento'],
                data: glucoseLogs
                    .map(
                      (l) => [
                        _getRelativeDate(
                          (l['created_at'] as Timestamp).toDate(),
                        ),
                        "${l['value'] ?? 0} mg/dL", // Uso de ?? 0 evita el error Null
                        l['timing'] ?? '-',
                      ],
                    )
                    .toList(),
              ),
            ],

            if (pressureLogs.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                "Presión Arterial",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Presión', 'Pulso'],
                data: pressureLogs
                    .map(
                      (l) => [
                        _getRelativeDate(
                          (l['created_at'] as Timestamp).toDate(),
                        ),
                        "${l['systolic'] ?? 0}/${l['diastolic'] ?? 0} mmHg",
                        "${l['pulse'] ?? 0} LPM",
                      ],
                    )
                    .toList(),
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
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

  Future<void> _linkPatient(String code) async {
    setState(() => _isSaving = true);
    try {
      // 1. Buscamos la conexión por el código
      final connectionDoc = await FirebaseFirestore.instance
          .collection('connections')
          .doc(code)
          .get();

      if (!connectionDoc.exists) {
        _showSnackBar(
          "Código no encontrado. Verifica con tu familiar.",
          Colors.red,
        );
        return;
      }

      String patientId = connectionDoc['patientId'];
      String patientName = connectionDoc['patientName'];

      // 2. Obtenemos el perfil del Paciente para ver su suscripción y cuántos tiene
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      final patientData = patientDoc.data() as Map<String, dynamic>;
      String plan =
          patientData['subscription_plan'] ??
          'free'; // 'basic', 'family', 'premium'
      int currentCaregivers = patientData['caregiversCount'] ?? 0;

      // 3. Lógica de validación de límites (Tus nuevos planes)
      int limit = 0;
      if (plan == 'basic') limit = 1; // Plan $4.99
      if (plan == 'family') limit = 3; // Plan $9.99
      if (plan == 'premium') limit = 999; // Plan $19.99 (Ilimitado)

      if (currentCaregivers >= limit) {
        _showSnackBar(
          "El paciente ya alcanzó el límite de cuidadores para su plan ($plan).",
          Colors.orange,
        );
        return;
      }

      // 4. Si pasa la validación, vinculamos
      final currentUser = FirebaseAuth.instance.currentUser;

      // Usamos un WriteBatch para que ambas actualizaciones ocurran o fallen juntas
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Actualizar al Cuidador
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(currentUser!.uid),
        {
          'linkedPatientId': patientId,
          'linkedPatientName': patientName,
          'role': 'caregiver',
        },
      );

      // Incrementar el contador en el Paciente
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(patientId),
        {'caregiversCount': FieldValue.increment(1)},
      );

      await batch.commit();
      _showSnackBar("¡Vinculación exitosa!", Colors.green);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
