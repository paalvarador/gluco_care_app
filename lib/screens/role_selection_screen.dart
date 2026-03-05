import 'package:flutter/material.dart';
import 'package:gluco_care_app/screens/register_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "¡Bienvenido a GlucoCare!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("Por favor, selecciona tu perfil para continuar:"),
              const SizedBox(height: 40),
              
              // Tarjeta para el Paciente (Tu mamá)
              _buildRoleCard(
                context,
                title: "Soy Paciente",
                subtitle: "Quiero registrar mis niveles de glucosa.",
                icon: Icons.person_pin_rounded,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen(role: 'patient')));
                },
              ),
              
              const SizedBox(height: 20),
              
              // Tarjeta para el Cuidador (Tú)
              _buildRoleCard(
                context,
                title: "Soy Cuidador",
                subtitle: "Quiero monitorear la salud de mi familiar.",
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen(role: 'caregiver')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, 
      {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}