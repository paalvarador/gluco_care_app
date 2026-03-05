import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InitialDashboard extends StatefulWidget {
  const InitialDashboard({super.key});

  @override
  State<InitialDashboard> createState() => _InitialDashboardState();
}

class _InitialDashboardState extends State<InitialDashboard> {
  bool _isSaving = false;

  // Función para guardar el rol en Firestore
  Future<void> _selectRole(String role) async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'full_name': user.displayName ?? 'Usuario',
          'email': user.email,
          'role': role,
          'subscription_status': 'free', // Iniciamos con el plan gratis
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "¡Casi listo!",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              const Text(
                "¿Cómo planeas usar Gluco Care?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              if (_isSaving)
                const CircularProgressIndicator()
              else ...[
                // Opción: PACIENTE
                _buildRoleCard(
                  title: "Soy Paciente",
                  description: "Quiero registrar mi glucosa y ver mis tendencias.",
                  icon: Icons.person_search_outlined,
                  color: Colors.blue.shade700,
                  onTap: () => _selectRole('patient'),
                ),
                
                const SizedBox(height: 20),
                
                // Opción: CUIDADOR
                _buildRoleCard(
                  title: "Soy Cuidador",
                  description: "Quiero supervisar las mediciones de mis seres queridos.",
                  icon: Icons.family_restroom_outlined,
                  color: Colors.teal.shade600,
                  onTap: () => _selectRole('caregiver'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}