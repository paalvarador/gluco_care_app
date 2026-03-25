import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_dashboard.dart';
import 'caregiver_dashboard.dart';

class InitialDashboard extends StatefulWidget {
  const InitialDashboard({super.key});

  @override
  State<InitialDashboard> createState() => _InitialDashboardState();
}

class _InitialDashboardState extends State<InitialDashboard> {
  bool _isSaving = false;

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
          'subscription_status': 'free',
          'created_at': FieldValue.serverTimestamp(),
          'caregivers_count': 0, // Inicializamos para evitar nulos
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => role == 'patient'
                ? const PatientDashboard()
                : const CaregiverDashboard(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al guardar: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FE,
      ), // El mismo fondo de tus Dashboards
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Icono de la App o un elemento visual de salud
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "¡Casi listo!",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2746),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Personaliza tu experiencia en Gluco Care.\n¿Cómo usarás la plataforma?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const Spacer(),

              if (_isSaving)
                const CircularProgressIndicator(color: Colors.blue)
              else ...[
                _buildRoleCard(
                  title: "Soy Paciente",
                  description:
                      "Registra glucosa, presión y genera reportes para tu doctor.",
                  icon: Icons.person_search_rounded,
                  color: Colors.blue.shade700,
                  onTap: () => _selectRole('patient'),
                ),
                const SizedBox(height: 20),
                _buildRoleCard(
                  title: "Soy Cuidador",
                  description:
                      "Monitorea la salud de tus familiares en tiempo real.",
                  icon: Icons.family_restroom_rounded,
                  color: const Color(
                    0xFF1E2746,
                  ), // Color oscuro para contraste Pro
                  onTap: () => _selectRole('caregiver'),
                ),
              ],
              const Spacer(),
              const Text(
                "Puedes cambiar de rol más adelante en ajustes.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 2,
          ), // Borde interno sutil
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2746),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
