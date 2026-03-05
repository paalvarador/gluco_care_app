import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Asegúrate de agregar intl en tu pubspec.yaml
import 'add_entry_modal.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Control de Glucosa"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos los cambios en la colección glucose_logs para este usuario
        stream: FirebaseFirestore.instance
            .collection('glucose_logs')
            .where('user_id', isEqualTo: user?.uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Aún no tienes registros.\n¡Presiona el botón + para empezar!",
                textAlign: TextAlign.center,
              ),
            );
          }

          // Tomamos la última medida para la tarjeta superior
          final lastEntry = docs.first.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "¡Hola de nuevo!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // TARJETA DINÁMICA DE ÚLTIMO REGISTRO
                _buildLatestSummary(lastEntry),

                const SizedBox(height: 30),
                const Text(
                  "Historial de registros",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // LISTA DINÁMICA
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildLogTile(data);
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEntry(context),
        label: const Text("Nuevo Registro"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildLatestSummary(Map<String, dynamic> data) {
    final int value = data['value'] ?? 0;
    final bool isHigh = data['is_high_risk'] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHigh ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHigh ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        children: [
          Text(
            "Última medición",
            style: TextStyle(
              color: isHigh ? Colors.red.shade900 : Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "$value mg/dL",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: isHigh ? Colors.red.shade900 : Colors.blue.shade900,
            ),
          ),
          Text(
            isHigh ? "Nivel Elevado" : "Nivel Normal",
            style: TextStyle(
              color: isHigh ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> data) {
    final DateTime date =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    final String timeFormatted = DateFormat('hh:mm a').format(date);
    final bool isHigh = data['is_high_risk'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          Icons.bloodtype,
          color: isHigh ? Colors.red : Colors.green,
        ),
        title: Text(
          "${data['value']} mg/dL",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(data['timing'] ?? ""),
        trailing: Text(
          timeFormatted,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  void _showAddEntry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => const AddEntryModal(),
    );
  }
}
