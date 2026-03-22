import 'package:cloud_firestore/cloud_firestore.dart';

class BloodPresureLog {
  final String? id;
  final String userId;
  final int systolic; // La "alta"
  final int diastolic; // La "baja"
  final int pulse; // Pulso/Frecuencia cardiaca
  final DateTime createdAt;
  final bool isHighRisk;
  final String? notes;

  BloodPresureLog({
    this.id,
    required this.userId,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.createdAt,
    required this.isHighRisk,
    this.notes,
  });

  // Para enviar el objeto a Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'timestamp': FieldValue.serverTimestamp(),
      'is_high_risk': isHighRisk,
      'notes': notes,
    };
  }
}
