import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/services/notification_service.dart';
import 'package:intl/intl.dart';

class AddMedicationModal extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const AddMedicationModal({super.key, this.docId, this.initialData});

  bool get isEditing => docId != null;

  @override
  State<AddMedicationModal> createState() => _AddMedicationModalState();
}

class _AddMedicationModalState extends State<AddMedicationModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedInterval = 24;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      _doseController.text = data['dosage'] ?? '';
      _selectedInterval = data['interval_hours'] ?? 24;
      final parts = (data['time'] as String? ?? '00:00').split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_nameController.text.isEmpty || _doseController.text.isEmpty) {
      _showError("Por favor llena todos los campos");
      return;
    }
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final scheduledDate = DateTime(
        now.year, now.month, now.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      final payload = {
        'user_id': user.uid,
        'name': _nameController.text,
        'dosage': _doseController.text,
        'time': DateFormat('HH:mm').format(scheduledDate),
        'interval_hours': _selectedInterval,
        'status': 'active',
      };

      if (widget.isEditing) {
        // Cancelar notificaciones antiguas antes de reprogramar
        await NotificationService.cancelMedication(
          widget.docId!.hashCode,
          slots: 3,
        );
        await FirebaseFirestore.instance
            .collection('medications')
            .doc(widget.docId)
            .update(payload);

        // Reprogramar con los nuevos datos
        if (_selectedInterval == 24) {
          await NotificationService.scheduleMedication(
            widget.docId!.hashCode,
            _nameController.text,
            _doseController.text,
            scheduledDate,
            medicationDocId: widget.docId!,
          );
        } else {
          await NotificationService.scheduleRecurringMedication(
            widget.docId!.hashCode,
            _nameController.text,
            _doseController.text,
            scheduledDate,
            _selectedInterval,
            medicationDocId: widget.docId!,
          );
        }
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('medications')
            .add({...payload, 'created_at': FieldValue.serverTimestamp()});

        if (_selectedInterval == 24) {
          await NotificationService.scheduleMedication(
            docRef.id.hashCode, _nameController.text,
            _doseController.text, scheduledDate,
            medicationDocId: docRef.id,
          );
        } else {
          await NotificationService.scheduleRecurringMedication(
            docRef.id.hashCode, _nameController.text,
            _doseController.text, scheduledDate, _selectedInterval,
            medicationDocId: docRef.id,
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError("Error al guardar: $e");
    }
  }

  void _showError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20, left: 25, right: 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isEditing ? "Editar Medicina" : "Nueva Medicina",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E2746),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: "Nombre de la medicina",
              prefixIcon: const Icon(Icons.medication_liquid_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 15),

          TextField(
            controller: _doseController,
            decoration: InputDecoration(
              labelText: "Dosis (ej: 1 tableta, 500mg)",
              prefixIcon: const Icon(Icons.monitor_weight_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 15),

          DropdownButtonFormField<int>(
            initialValue: _selectedInterval,
            decoration: InputDecoration(
              labelText: "Frecuencia",
              prefixIcon: const Icon(Icons.repeat_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
            items: const [
              DropdownMenuItem(value: 8,  child: Text("Cada 8 horas (3 veces al día)")),
              DropdownMenuItem(value: 12, child: Text("Cada 12 horas (2 veces al día)")),
              DropdownMenuItem(value: 24, child: Text("Una vez al día")),
            ],
            onChanged: (val) => setState(() => _selectedInterval = val!),
          ),
          const SizedBox(height: 10),

          ListTile(
            title: const Text("Hora de la primera toma"),
            subtitle: Text(
              _selectedTime.format(context),
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent,
              ),
            ),
            leading: const Icon(Icons.alarm, color: Colors.blueAccent),
            onTap: () async {
              final picked = await showTimePicker(
                context: context, initialTime: _selectedTime,
              );
              if (picked != null) setState(() => _selectedTime = picked);
            },
          ),

          const SizedBox(height: 30),

          _isSaving
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    widget.isEditing ? "Guardar Cambios" : "Programar Recordatorio",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
