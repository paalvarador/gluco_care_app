import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gluco_care_app/screens/welcome_screen.dart';
import 'package:gluco_care_app/screens/patient_dashboard.dart';
import 'package:gluco_care_app/screens/caregiver_dashboard.dart';
import 'firebase_options.dart';
import 'package:gluco_care_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicialización Notificaciones
  await NotificationService.init();

  // --- CONFIGURACIÓN MODO OFFLINE (PERSISTENCIA) ---
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Datos siempre disponibles
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlucoCare',
      debugShowCheckedModeBanner: false,

      // TEMA CLARO: Limpio y profesional
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(
          0xFF1E2746,
        ), // Esto genera toda la paleta sola
        brightness: Brightness.light,
      ),

      // TEMA OSCURO: Automático y elegante
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E2746), // El mismo color semilla
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),

      themeMode: ThemeMode.system, // Cambia según el iPhone o Android
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const WelcomeScreen();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userSnapshot.data?.data() as Map<String, dynamic>?;
            if (data == null || !data.containsKey('role')) {
              // Usuario sin rol asignado aún → flujo de login normal
              return const WelcomeScreen();
            }

            return data['role'] == 'caregiver'
                ? const CaregiverDashboard()
                : const PatientDashboard();
          },
        );
      },
    );
  }
}
