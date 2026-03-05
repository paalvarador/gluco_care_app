import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gluco_care_app/screens/caregiver_dashboard.dart';
import 'package:gluco_care_app/screens/login_screen.dart';
import 'package:gluco_care_app/screens/role_selection_screen.dart';
import 'patient_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        if (!snapshot.hasData) return const LoginScreen(); // Nadie logueado -> Login

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

            // Si el usuario existe pero no tiene rol en Firestore -> Pantalla de elegir rol
            if (userSnap.hasData && !userSnap.data!.exists) {
              return const RoleSelectionScreen(); 
            }

            // Si ya tiene rol, mandarlo a su dashboard
            String role = userSnap.data!.get('role');
            return role == 'patient' ? const PatientDashboard() : const CaregiverDashboard();
          },
        );
      },
    );
  }
}