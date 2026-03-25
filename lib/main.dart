import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- IMPORTANTE
import 'package:gluco_care_app/screens/auth_wrapper.dart';
import 'package:gluco_care_app/screens/welcome_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const WelcomeScreen(),
    );
  }
}
