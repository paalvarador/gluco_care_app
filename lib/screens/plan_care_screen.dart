import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/screens/add_appointment_modal.dart';
import 'package:gluco_care_app/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'add_medication_modal.dart';

// Returns today's date as 'yyyy-MM-dd' string
String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

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
    await NotificationService.cancelAppointment(docId.hashCode);
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
            return _MedicationCard(
              docId: doc.id,
              med: med,
              uid: uid ?? '',
              onEdit: () => _openMedicationModal(context, docId: doc.id, data: med),
              onDelete: () => _deleteMedication(context, doc.id, med['name'] ?? ''),
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

        final now = DateTime.now();
        final all = snapshot.data!.docs.toList();

        final upcoming = all
            .where((d) =>
                (d['appointment_date'] as Timestamp).toDate().isAfter(now))
            .toList()
          ..sort((a, b) =>
              (a['appointment_date'] as Timestamp)
                  .toDate()
                  .compareTo((b['appointment_date'] as Timestamp).toDate()));

        final past = all
            .where((d) =>
                !(d['appointment_date'] as Timestamp).toDate().isAfter(now))
            .toList()
          ..sort((a, b) =>
              (b['appointment_date'] as Timestamp)
                  .toDate()
                  .compareTo((a['appointment_date'] as Timestamp).toDate()));

        if (all.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No tienes citas médicas programadas.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return Column(
          children: [
            // ── Próximas ─────────────────────────────────────────
            if (upcoming.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "No tienes citas próximas.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcoming.length,
                itemBuilder: (context, index) {
                  final doc  = upcoming[index];
                  final appt = doc.data() as Map<String, dynamic>;
                  final date = (appt['appointment_date'] as Timestamp).toDate();
                  return _appointmentCard(
                    context, doc.id, appt, date, past: false,
                  );
                },
              ),

            // ── Pasadas (colapsable) ──────────────────────────────
            if (past.isNotEmpty) ...[
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    "Citas pasadas (${past.length})",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  iconColor: Colors.grey,
                  collapsedIconColor: Colors.grey,
                  children: past.map((doc) {
                    final appt = doc.data() as Map<String, dynamic>;
                    final date =
                        (appt['appointment_date'] as Timestamp).toDate();
                    return _appointmentCard(
                      context, doc.id, appt, date, past: true,
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _appointmentCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> appt,
    DateTime date, {
    required bool past,
  }) {
    final iconColor   = past ? Colors.grey.shade400 : Colors.redAccent;
    final iconBg      = past
        ? Colors.grey.shade100
        : Colors.redAccent.withValues(alpha: 0.1);
    final titleStyle  = TextStyle(
      fontWeight: FontWeight.bold,
      color: past ? Colors.grey.shade500 : null,
    );
    final subtitleText =
        "${appt['specialty'] ?? ''} • ${DateFormat('dd/MM/yyyy  HH:mm').format(date)}";

    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: past ? Colors.grey.shade200 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.event_note_rounded, color: iconColor),
        ),
        title: Text(appt['doctor_name'] ?? "Cita Médica", style: titleStyle),
        subtitle: past
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitleText,
                      style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Completada",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : Text(subtitleText),
        trailing: past
            ? IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.grey.shade400, size: 20),
                onPressed: () =>
                    _deleteAppointment(context, docId, appt['doctor_name'] ?? ''),
              )
            : _actionMenu(
                context,
                onEdit: () => _openAppointmentModal(
                  context,
                  docId: docId,
                  data: appt,
                ),
                onDelete: () =>
                    _deleteAppointment(context, docId, appt['doctor_name'] ?? ''),
              ),
      ),
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

// ── Tarjeta de medicamento con estado "Ya tomé" ──────────────────
class _MedicationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> med;
  final String uid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicationCard({
    required this.docId,
    required this.med,
    required this.uid,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _markTaken(BuildContext context) async {
    final baseId = docId.hashCode;
    await NotificationService.markTaken(baseId, docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Registro guardado! Recordatorios cancelados para hoy.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medication_logs')
          .where('user_id', isEqualTo: uid)
          .where('medication_id', isEqualTo: docId)
          .where('date', isEqualTo: _todayStr())
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final taken = snap.hasData && snap.data!.docs.isNotEmpty;
        return Card(
          margin: const EdgeInsets.only(top: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.medication,
                  color: taken ? Colors.green : Colors.blue,
                ),
                title: Text(
                  med['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${med['dosage'] ?? ''} • ${med['time'] ?? ''}"),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 10),
                        Text("Editar"),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
                      ]),
                    ),
                  ],
                ),
              ),
              if (!taken)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _markTaken(context),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text("Ya tomé mi medicina"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Tomada hoy",
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
