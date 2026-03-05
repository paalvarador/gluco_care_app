import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CaregiverDashboard extends StatelessWidget {
  const CaregiverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Control (Cuidador)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Aquí podrías filtrar por un 'patient_id' vinculado en el futuro
        // Por ahora, vemos todos los registros de la base para monitoreo
        stream: FirebaseFirestore.instance
            .collection('glucose_logs')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final logs = snapshot.data?.docs ?? [];
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Resumen de Pacientes", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Tarjeta de Estado del Paciente Principal (Tu mamá)
                _buildPatientSummaryCard(logs),
                
                const SizedBox(height: 30),
                const Text("Alertas Recientes", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 10),
                
                // Lista de solo las alertas de alto riesgo
                ...logs.where((doc) => doc['is_high_risk'] == true).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildAlertTile(data);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientSummaryCard(List<QueryDocumentSnapshot> logs) {
    if (logs.isEmpty) return const Card(child: ListTile(title: Text("Sin datos")));

    // Cálculo básico de promedio
    double avg = logs.map((doc) => (doc['value'] as int)).reduce((a, b) => a + b) / logs.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text("Mi Paciente (Mamá)", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Monitoreo activo"),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Promedio", "${avg.toStringAsFixed(0)} mg/dL"),
                _buildStat("Registros", "${logs.length}"),
                _buildStat("Estado", avg > 150 ? "Alerta" : "Estable", 
                  color: avg > 150 ? Colors.orange : Colors.green),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color color = Colors.black}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> data) {
    final DateTime date = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        title: Text("Glucosa Alta: ${data['value']} mg/dL"),
        subtitle: Text("${data['timing']} - ${DateFormat('dd MMM, hh:mm a').format(date)}"),
      ),
    );
  }
}