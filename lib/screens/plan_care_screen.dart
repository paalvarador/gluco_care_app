import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/screens/add_appointment_modal.dart';
import 'package:intl/intl.dart';
import 'add_medication_modal.dart'; // El que creamos antes

class PlanCareScreen extends StatelessWidget {
  const PlanCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Mi Plan de Cuidado",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              context,
              "Mis Medicinas",
              () => _showAddMedication(context),
            ),
            _buildMedicationList(user?.uid),
            const SizedBox(height: 30),
            _sectionHeader(context, "Citas Médicas", () {
              _showAddAppointment(context);
            }),
            _buildAppointmentsList(user?.uid),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    VoidCallback onAdd,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
        ),
      ],
    );
  }

  Widget _buildMedicationList(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medications')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;

        if (docs.isEmpty)
          return const Text(
            "No tienes medicinas programadas",
            style: TextStyle(color: Colors.grey),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final med = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(top: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(Icons.medication, color: Colors.blue),
                title: Text(
                  med['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${med['dosage']} • ${med['time']}"),
                trailing: const Icon(
                  Icons.notifications_active,
                  size: 18,
                  color: Colors.green,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentsList(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments') // Nombre de la nueva colección
          .where('user_id', isEqualTo: uid)
          .orderBy('date_time', descending: false) // Las más cercanas primero
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Error al cargar citas");
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No tienes citas médicas programadas.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final appt = docs[index].data() as Map<String, dynamic>;
            final DateTime date = (appt['date_time'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.only(top: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: Text(
                  appt['doctor_name'] ?? "Cita Médica",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${appt['specialty']} • ${DateFormat('dd/MM - hh:mm a').format(date)}",
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMedication(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Esto permite que suba más allá de la mitad
      backgroundColor:
          Colors.transparent, // Para que se vea el borde redondeado que hicimos
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, // Altura inicial (70% de la pantalla)
        maxChildSize: 0.9, // Altura máxima
        minChildSize: 0.5, // Altura mínima
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: const AddMedicationModal(),
            ),
          );
        },
      ),
    );
  }

  void _showAddAppointment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Importante para que no se corte con el teclado
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: const AddAppointmentModal(), // Llamamos al archivo que creamos
      ),
    );
  }
}
