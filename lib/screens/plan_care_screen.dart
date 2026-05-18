import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/screens/add_appointment_modal.dart';
import 'package:gluco_care_app/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'add_medication_modal.dart';

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
            _sectionHeader(context, "Mis Medicinas",
                () => _openMedicationModal(context)),
            _buildMedicationList(context, user?.uid),
            const SizedBox(height: 30),
            _sectionHeader(context, "Citas Médicas",
                () => _openAppointmentModal(context)),
            _buildAppointmentsList(context, user?.uid),
          ],
        ),
      ),
    );
  }

  // ── Helpers de apertura de modales ──────────────────────────────

  void _openMedicationModal(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: AddMedicationModal(docId: docId, initialData: data),
          ),
        ),
      ),
    );
  }

  void _openAppointmentModal(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? data,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: AddAppointmentModal(docId: docId, initialData: data),
      ),
    );
  }

  // ── Borrar ───────────────────────────────────────────────────────

  Future<void> _deleteMedication(
      BuildContext context, String docId, String name) async {
    final confirmed = await _confirmDelete(context, name, isMed: true);
    if (!confirmed) return;
    await NotificationService.cancelMedication(docId.hashCode, slots: 3);
    await FirebaseFirestore.instance
        .collection('medications')
        .doc(docId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicina eliminada")),
      );
    }
  }

  Future<void> _deleteAppointment(
      BuildContext context, String docId, String doctor) async {
    final confirmed = await _confirmDelete(context, doctor, isMed: false);
    if (!confirmed) return;
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(docId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cita eliminada")),
      );
    }
  }

  Future<bool> _confirmDelete(
      BuildContext context, String name, {required bool isMed}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text("¿Eliminar ${isMed ? 'medicina' : 'cita'}?"),
            content: Text(
              "Se eliminará \"$name\"${isMed ? ' y sus recordatorios' : ''}. Esta acción no se puede deshacer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCELAR"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white),
                child: const Text("ELIMINAR"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Encabezado de sección ────────────────────────────────────────

  Widget _sectionHeader(
      BuildContext context, String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: onAdd,
          icon:
              const Icon(Icons.add_circle, color: Colors.blueAccent),
        ),
      ],
    );
  }

  // ── Lista de medicamentos ────────────────────────────────────────

  Widget _buildMedicationList(BuildContext context, String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medications')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text(
            "No tienes medicinas programadas",
            style: TextStyle(color: Colors.grey),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final med = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(top: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading:
                    const Icon(Icons.medication, color: Colors.blue),
                title: Text(med['name'] ?? '',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "${med['dosage'] ?? ''} • ${med['time'] ?? ''}"),
                trailing: _actionMenu(
                  context,
                  onEdit: () => _openMedicationModal(
                    context,
                    docId: doc.id,
                    data: med,
                  ),
                  onDelete: () =>
                      _deleteMedication(context, doc.id, med['name'] ?? ''),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Lista de citas ───────────────────────────────────────────────

  Widget _buildAppointmentsList(BuildContext context, String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('user_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Error citas: ${snapshot.error}");
          return const Text("Error al cargar citas");
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aDate =
                (a['appointment_date'] as Timestamp).toDate();
            final bDate =
                (b['appointment_date'] as Timestamp).toDate();
            return aDate.compareTo(bDate);
          });

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
            final doc  = docs[index];
            final appt = doc.data() as Map<String, dynamic>;
            final DateTime date =
                (appt['appointment_date'] as Timestamp).toDate();

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
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_note_rounded,
                      color: Colors.redAccent),
                ),
                title: Text(
                  appt['doctor_name'] ?? "Cita Médica",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${appt['specialty']} • ${DateFormat('dd/MM/yyyy  HH:mm').format(date)}",
                ),
                trailing: _actionMenu(
                  context,
                  onEdit: () => _openAppointmentModal(
                    context,
                    docId: doc.id,
                    data: appt,
                  ),
                  onDelete: () => _deleteAppointment(
                      context, doc.id, appt['doctor_name'] ?? ''),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Menú contextual (tres puntos) ────────────────────────────────

  Widget _actionMenu(
    BuildContext context, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text("Editar"),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}
