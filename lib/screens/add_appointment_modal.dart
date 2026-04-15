import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddAppointmentModal extends StatefulWidget {
  const AddAppointmentModal({super.key});

  @override
  State<AddAppointmentModal> createState() => _AddAppointmentModalState();
}

class _AddAppointmentModalState extends State<AddAppointmentModal> {
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  void _saveAppointment() async {
    if (_doctorController.text.isEmpty || _specialtyController.text.isEmpty) {
      _showError("Por favor llena el nombre del Dr. y la especialidad");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Unimos fecha y hora en un solo DateTime
      final appointmentDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Guardamos en la colección 'appointments'
      await FirebaseFirestore.instance.collection('appointments').add({
        'user_id': user.uid,
        'doctor_name': _doctorController.text,
        'specialty': _specialtyController.text,
        'notes': _notesController.text,
        'appointment_date': Timestamp.fromDate(appointmentDateTime),
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError("Error al guardar: ${e.toString()}");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20, left: 25, right: 25,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Línea estética superior
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(
              "Nueva Cita Médica",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : const Color(0xFF1E2746)
              ),
            ),
            const SizedBox(height: 25),
            
            TextField(
              controller: _doctorController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "Nombre del Doctor",
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _specialtyController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Especialidad (ej: Endocrinólogo)",
                prefixIcon: const Icon(Icons.medical_services_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Fecha", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.calendar_month_outlined, color: Colors.blueAccent),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Hora", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Notas u Observaciones",
                prefixIcon: const Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),

            const SizedBox(height: 30),

            _isSaving
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveAppointment,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: const Color(0xFF1E2746), // Tu azul oscuro
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("Guardar Cita", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}