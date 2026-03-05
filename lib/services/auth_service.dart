import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registro con Email, Password y Role
  Future<User?> registerWithEmail(String email, String password, String fullName, String role) async {
    try {
      // 1. Crear el usuario en Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;

      if (user != null) {
        // 2. Guardar los datos adicionales en Firestore usando las tablas en inglés que definimos
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'full_name': fullName,
          'email': email,
          'role': role, // 'patient' o 'caregiver'
          'subscription_status': 'trial',
          'trial_end_date': DateTime.now().add(const Duration(days: 7)),
          'created_at': FieldValue.serverTimestamp(),
          'customer_id': '', // Se llenará con RevenueCat después
        });
      }
      return user;
    } catch (e) {
      debugPrint("Error en registro: ${e.toString()}");
      return null;
    }
  }
}