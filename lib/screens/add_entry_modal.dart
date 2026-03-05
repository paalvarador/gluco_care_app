import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEntryModal extends StatefulWidget {
  const AddEntryModal({super.key});

  @override
  State<AddEntryModal> createState() => _AddEntryModalState();
}

class _AddEntryModalState extends State<AddEntryModal> {
  int _glucoseValue = 100;
  String _selectedTiming = 'Ayunas';
  bool _isSaving = false;

  final List<String> _timings = [
    'Ayunas', 
    'Antes de comer', 
    'Después de comer', 
    'Antes de dormir'
  ];

  void _saveLog() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Definimos riesgo si es mayor a 180 (puedes ajustarlo)
      bool isHighRisk = _glucoseValue > 180;

      await FirebaseFirestore.instance.collection('glucose_logs').add({
        'user_id': user.uid,
        'value': _glucoseValue,
        'timing': _selectedTiming,
        'created_at': FieldValue.serverTimestamp(),
        'is_high_risk': isHighRisk,
      });

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20, left: 20, right: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Nuevo Registro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Selector de valor (mg/dL)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _glucoseValue--),
                icon: const Icon(Icons.remove_circle_outline, size: 40, color: Colors.red),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("$_glucoseValue", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () => setState(() => _glucoseValue++),
                icon: const Icon(Icons.add_circle_outline, size: 40, color: Colors.green),
              ),
            ],
          ),
          const Text("mg/dL", style: TextStyle(color: Colors.grey)),
          
          const SizedBox(height: 30),
          
          // Selector de momento (Chips)
          Wrap(
            spacing: 8,
            children: _timings.map((t) => ChoiceChip(
              label: Text(t),
              selected: _selectedTiming == t,
              onSelected: (val) => setState(() => _selectedTiming = t),
            )).toList(),
          ),
          
          const SizedBox(height: 30),
          
          _isSaving 
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _saveLog,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: const Text("Guardar Registro", style: TextStyle(fontSize: 18)),
              ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}