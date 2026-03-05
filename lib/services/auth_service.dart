import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registro con Email, Password y Role
  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    try {
      // 1. Crear el usuario en Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
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

  Future<User?> signInWithGoogle(String role) async {
    try {
      // 1. Iniciar el flujo de inicio de sesión de Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // El usuario canceló la operación

      // 2. Obtener los detalles de autenticación de la solicitud
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Crear una nueva credencial
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase con la credencial de Google
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        // 5. Verificar si el usuario ya existe en Firestore con un tiempo límite de 10 segundos
        // Esto evita que la app se quede cargando infinitamente si hay un error de red
        final userDoc = await _db
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (!userDoc.exists) {
          // 6. Si es un usuario nuevo, guardamos su perfil con el rol seleccionado (patient/caregiver)
          await _db.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'full_name': user.displayName ?? 'Usuario',
            'email': user.email,
            'role': role, //
            'subscription_status': 'trial', //
            'trial_end_date': DateTime.now().add(const Duration(days: 7)), //
            'created_at': FieldValue.serverTimestamp(), //
            'customer_id': '', // Para futura integración con RevenueCat
          });
        }
      }
      return user;
    } catch (e) {
      // Log del error para depuración
      debugPrint("Error en signInWithGoogle: ${e.toString()}");
      return null;
    }
  }
}
