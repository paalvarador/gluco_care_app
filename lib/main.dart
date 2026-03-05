import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gluco_care_app/screens/auth_wrapper.dart';
import 'package:gluco_care_app/screens/welcome_screen.dart';
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
      home: WelcomeScreen(), // Iniciamos con la selección
    );
  }
}