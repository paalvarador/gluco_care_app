import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'patient_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Si está cargando el estado de la conexión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. Si NO hay un usuario logueado, vamos a la selección de rol
        if (!snapshot.hasData) {
          return const RoleSelectionScreen();
        }

        // 3. Si HAY un usuario, consultamos su rol en Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(snapshot.data!.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              String role = userSnapshot.data!.get('role');

              if (role == 'patient') {
                return const PatientDashboard();
              } else {
                // Aquí irá el Dashboard del Cuidador cuando lo creemos
                return const Scaffold(body: Center(child: Text("Panel de Cuidador (En construcción)")));
              }
            }

            // En caso de error o si el documento no existe
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}