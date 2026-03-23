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
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // --- CAMBIO PARA EL SAAS ---
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'full_name': fullName,
          'email': email,
          'role': role,
          'subscription_status': 'free', // Iniciamos en Free de ley
          'caregivers_count': 0, // Contador de cuidadores vinculados
          'created_at': FieldValue.serverTimestamp(),
          'customer_id': '', // Para RevenueCat/Stripe
        });
      }
      return user;
    } catch (e) {
      debugPrint("Error en registro: ${e.toString()}");
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      // 1. CONFIGURACIÓN CRÍTICA PARA ANDROID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        // REEMPLAZA ESTO con el "Web client ID" que copiamos de Google Cloud Console
        // El que termina en .apps.googleusercontent.com
        serverClientId:
            '733119792621-g7hnf8utvegosd2jkn1cfb6mcudut5pn.apps.googleusercontent.com',
        scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
      );

      // 2. INICIAR EL FLUJO
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      debugPrint("Error detallado en Google SignIn: $e");
      return null;
    }
  }

  // Nueva función para asignar rol solo a usuarios nuevos
  Future<void> setUserRole(
    String uid,
    String role,
    String email,
    String name,
  ) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'full_name': name,
      'email': email,
      'role': role,
      'subscription_status': 'free', // Plan inicial
      'caregivers_count': 0, // Necesario para validar el límite
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
