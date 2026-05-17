import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Email / Password ───────────────────────────────────────────
  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'full_name': fullName,
          'email': email,
          'role': role,
          'subscription_status': 'free',
          'caregivers_count': 0,
          'created_at': FieldValue.serverTimestamp(),
          'customer_id': '',
        });
      }
      return user;
    } catch (e) {
      debugPrint("Error en registro: $e");
      return null;
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
            '733119792621-g7hnf8utvegosd2jkn1cfb6mcudut5pn.apps.googleusercontent.com',
        scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } catch (e) {
      debugPrint("Error en Google SignIn: $e");
      return null;
    }
  }

  // ── Apple Sign In ──────────────────────────────────────────────
  Future<User?> signInWithApple() async {
    try {
      // Nonce seguro para evitar ataques de replay
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;

      // Apple solo devuelve nombre en el PRIMER login — lo guardamos inmediatamente
      if (user != null && result.additionalUserInfo?.isNewUser == true) {
        final fullName = [
          appleCredential.givenName ?? '',
          appleCredential.familyName ?? '',
        ].where((s) => s.isNotEmpty).join(' ');

        if (fullName.isNotEmpty) {
          await user.updateDisplayName(fullName);
        }
      }

      return user;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        debugPrint("Error Apple SignIn: ${e.message}");
      }
      return null;
    } catch (e) {
      debugPrint("Error Apple SignIn: $e");
      return null;
    }
  }

  // ── Rol para usuarios nuevos (Google / Apple) ──────────────────
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
      'subscription_status': 'free',
      'caregivers_count': 0,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Helpers para el nonce ──────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
