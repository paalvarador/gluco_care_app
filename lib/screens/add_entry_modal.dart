import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEntryModal extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddEntryModal({super.key, this.initialData});

  @override
  State<AddEntryModal> createState() => _AddEntryModalState();
}

class _AddEntryModalState extends State<AddEntryModal> {
  // 1. Selector de tipo: 0 para Glucosa, 1 para Presión
  int _selectedTypeIndex = 0;

  // Variables de Glucosa
  int _glucoseValue = 100;
  String _selectedTiming = 'Ayunas';
  final List<String> _timings = [
    'Ayunas',
    'Antes de comer',
    'Después de comer',
    'Antes de dormir',
  ];

  // Variables de Presión Arterial (NUEVO VALOR)
  int _systolic = 120;
  int _diastolic = 80;
  int _pulse = 70;

  bool _isSaving = false;

  void _saveLog() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Obtenemos el ID y la colección
      final String? docId = widget.initialData?['id'];
      final String collection = _selectedTypeIndex == 0
          ? 'glucose_logs'
          : 'blood_pressure_logs';

      Map<String, dynamic> logData = {
        'user_id': user.uid,
        'is_high_risk': _selectedTypeIndex == 0
            ? _glucoseValue > 180
            : (_systolic >= 140 || _diastolic >= 90),
      };

      if (_selectedTypeIndex == 0) {
        logData.addAll({'value': _glucoseValue, 'timing': _selectedTiming});
      } else {
        logData.addAll({
          'systolic': _systolic,
          'diastolic': _diastolic,
          'pulse': _pulse,
        });
      }

      if (docId != null) {
        // MODO EDICIÓN
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .update(logData);
      } else {
        // MODO NUEVO
        logData['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection(collection).add(logData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      final data = widget.initialData!;

      // Detectamos si es Glucosa o Persión para poner el selector en el lugar correcto
      _selectedTypeIndex = data['type'] == 'glucose' ? 0 : 1;

      if (_selectedTypeIndex == 0) {
        _glucoseValue = data['value'] ?? 100;
        _selectedTiming = data['timing'] ?? 'Ayunas';
      } else {
        _systolic = data['systolic'] ?? 120;
        _diastolic = data['diastolic'] ?? 80;
        _pulse = data['pulse'] ?? 70;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SELECTOR DE TIPO (Esto es lo que faltaba para que se vea el cambio)
          ToggleButtons(
            isSelected: [_selectedTypeIndex == 0, _selectedTypeIndex == 1],
            onPressed: (index) => setState(() => _selectedTypeIndex = index),
            borderRadius: BorderRadius.circular(10),
            selectedColor: Colors.white,
            fillColor: _selectedTypeIndex == 0
                ? Colors.blueAccent
                : Colors.redAccent,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("Glucosa"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("Presión"),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // MOSTRAR CAMPOS SEGÚN SELECCIÓN
          if (_selectedTypeIndex == 0)
            _buildGlucoseEditor()
          else
            _buildPressureEditor(),

          const SizedBox(height: 30),

          _isSaving
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: _selectedTypeIndex == 0
                        ? Colors.blueAccent
                        : Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    widget.initialData != null
                        ? "Actualizar Registro"
                        : "Guardar Registro",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildGlucoseEditor() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _counterBtn(
              () => setState(() => _glucoseValue--),
              Icons.remove_circle_outline,
              Colors.red,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "$_glucoseValue",
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _counterBtn(
              () => setState(() => _glucoseValue++),
              Icons.add_circle_outline,
              Colors.green,
            ),
          ],
        ),
        const Text("mg/dL", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          children: _timings
              .map(
                (t) => ChoiceChip(
                  label: Text(t),
                  selected: _selectedTiming == t,
                  onSelected: (val) => setState(() => _selectedTiming = t),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPressureEditor() {
    return Column(
      children: [
        _pressureRow(
          "Sistólica (Alta)",
          _systolic,
          (val) => setState(() => _systolic = val),
          Colors.redAccent,
        ),
        const SizedBox(height: 15),
        _pressureRow(
          "Diastólica (Baja)",
          _diastolic,
          (val) => setState(() => _diastolic = val),
          Colors.blue,
        ),
        const SizedBox(height: 15),
        _pressureRow(
          "Pulso (LPM)",
          _pulse,
          (val) => setState(() => _pulse = val),
          Colors.green,
        ),
      ],
    );
  }

  Widget _pressureRow(
    String label,
    int value,
    Function(int) onChanged,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            _counterBtn(() => onChanged(value - 1), Icons.remove, color),
            SizedBox(
              width: 50,
              child: Center(
                child: Text(
                  "$value",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _counterBtn(() => onChanged(value + 1), Icons.add, color),
          ],
        ),
      ],
    );
  }

  Widget _counterBtn(VoidCallback onPressed, IconData icon, Color color) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 30, color: color),
    );
  }
}
