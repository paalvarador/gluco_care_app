import 'package:cloud_firestore/cloud_firestore.dart';

class GlucoseLog {
  final String? id;
  final String userId;
  final int value;
  final String timing; // Ayunas, Antes de comer, etc.
  final DateTime createdAt;
  final bool isHighRisk;

  GlucoseLog({
    this.id,
    required this.userId,
    required this.value,
    required this.timing,
    required this.createdAt,
    required this.isHighRisk,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'value': value,
      'timing': timing,
      'created_at': FieldValue.serverTimestamp(),
      'is_high_risk': isHighRisk,
    };
  }
}