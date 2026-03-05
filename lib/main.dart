import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/role_selection_screen.dart'; // Importa tu pantalla
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RoleSelectionScreen(), // Iniciamos con la selección
    );
  }
}