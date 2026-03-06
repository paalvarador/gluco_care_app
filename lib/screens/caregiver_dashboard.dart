import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    final DateTime limit24h = DateTime.now().subtract(const Duration(hours: 24));

    return StreamBuilder<DocumentSnapshot>(
      // ESCUCHA 1: Tu perfil de usuario. Si 'linkedPatientId' cambia en Firestore, esto se dispara solo.
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String? linkedId = userData?['linkedPatientId'];
        final String? linkedName = userData?['linkedPatientName'] ?? "Mi Paciente";
        final bool isPremiumUser = userData?['subscription_status'] == 'premium';

        // SI NO HAY VÍNCULO: Mostramos la pantalla para ingresar el código
        if (linkedId == null) {
          return _buildEmptyState();
        }

        // SI HAY VÍNCULO: Mostramos el Dashboard reactivo
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text("Monitoreo: $linkedName",
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.blue),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            // ESCUCHA 2: Registros de glucosa filtrados por el familiar vinculado
            stream: FirebaseFirestore.instance
                .collection('glucose_logs')
                .where('user_id', isEqualTo: linkedId) 
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final allLogs = snapshot.data!.docs;

              // Lógica de Muro de Pago: Solo últimas 24 horas si no es Premium
              final logs = isPremiumUser
                  ? allLogs
                  : allLogs.where((doc) {
                      final timestamp = doc['created_at'] as Timestamp?;
                      if (timestamp == null) return false;
                      return timestamp.toDate().isAfter(limit24h);
                    }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPremiumBanner(isPremiumUser),
                    const SizedBox(height: 20),
                    _buildPatientSummaryCard(logs),
                    const SizedBox(height: 25),
                    _buildSectionHeader("Alertas Críticas", Colors.red),
                    const SizedBox(height: 10),
                    ...logs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['is_high_risk'] == true;
                    }).map((doc) => _buildAlertTile(doc.data() as Map<String, dynamic>)),

                    if (!isPremiumUser && allLogs.length > logs.length)
                      _buildLockedHistoryInfo(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- LÓGICA DE VINCULACIÓN ---

  Future<void> _linkPatient(String code) async {
    setState(() => _isSaving = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('connections').doc(code).get();

      if (doc.exists) {
        String patientId = doc['patientId'];
        String patientName = doc['patientName'];

        final currentUser = FirebaseAuth.instance.currentUser;
        
        // Al actualizar Firestore, el StreamBuilder del build() detectará el cambio automáticamente
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
          'linkedPatientId': patientId,
          'linkedPatientName': patientName,
        });

        _showSnackBar("¡Vinculación exitosa!", Colors.green);
      } else {
        _showSnackBar("Código no encontrado. Verifica con tu familiar.", Colors.red);
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
              const Text("Aún no tienes a nadie vinculado",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Pide el código de vinculación a tu familiar para empezar el monitoreo.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              _isSaving 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _showLinkCodeDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          decoration: const InputDecoration(hintText: "Ej: ABC123", border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
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
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[600]!]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Desbloquea el historial", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Accede a más de 24 horas de datos.", 
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {}, // Aquí conectas tu flujo de In-App Purchase de $4.99
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, 
              foregroundColor: Colors.blue[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: const Text("PREMIUM"),
          )
        ],
      ),
    );
  }

  Widget _buildPatientSummaryCard(List<QueryDocumentSnapshot> logs) {
    if (logs.isEmpty) {
      return const Card(child: ListTile(title: Text("Sin registros en las últimas 24h")));
    }
    double avg = logs.map((doc) => (doc['value'] as int)).reduce((a, b) => a + b) / logs.length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
              title: Text("Mi Paciente (Mamá)", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Estado en tiempo real"),
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Promedio", "${avg.toStringAsFixed(0)}"),
                _buildStat("Registros", "${logs.length}"),
                _buildStat("Nivel", avg > 150 ? "Alto" : "Normal", color: avg > 150 ? Colors.orange : Colors.green),
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
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> data) {
    final DateTime date = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.red[50],
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: Text("Glucosa Alta: ${data['value']} mg/dL", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        subtitle: Text("${data['timing']} • ${DateFormat('hh:mm a').format(date)}"),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color));
  }

  Widget _buildLockedHistoryInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Icon(Icons.lock_person_rounded, color: Colors.grey[400], size: 50),
          const SizedBox(height: 10),
          const Text("Días anteriores bloqueados", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("Suscríbete por \$4.99 para ver todo el historial.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}