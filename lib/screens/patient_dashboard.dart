import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/screens/add_entry_modal.dart';
import '../services/auth_service.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Control de Glucosa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Implementaremos el logout después
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¡Hola de nuevo!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Tarjeta de Último Registro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    "Última medición",
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "115 mg/dL", // Esto vendrá de Firestore luego
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const Text(
                    "Hace 2 horas (Ayunas)",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              "Registros de hoy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Lista simple de ejemplo
            _buildLogTile("08:30 AM", "110 mg/dL", "Ayunas"),
            _buildLogTile("02:00 PM", "145 mg/dL", "Después de almuerzo"),
          ],
        ),
      ),

      // BOTÓN GRANDE PARA REGISTRAR
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            builder: (context) => const AddEntryModal(),
          );
        },
        label: const Text("Nuevo Registro"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildLogTile(String time, String value, String note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.bloodtype, color: Colors.redAccent),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(note),
        trailing: Text(time, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}
