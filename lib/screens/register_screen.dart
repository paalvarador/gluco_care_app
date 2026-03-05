import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final String role; // Recibe 'patient' o 'caregiver'
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final user = await AuthService().registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        widget.role,
      );

      setState(() => _isLoading = false);

      if (user != null) {
        // Registro exitoso -> Ir al Home correspondiente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Cuenta creada con éxito!")),
        );
        // Aquí luego pondremos la lógica para ir a la pantalla de tu mamá o la tuya
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al registrar. Revisa tus datos.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Registro como ${widget.role == 'patient' ? 'Paciente' : 'Cuidador'}")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Nombre Completo", border: OutlineInputBorder()),
                  validator: (val) => val!.isEmpty ? "Ingresa tu nombre" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                  validator: (val) => val!.isEmpty ? "Ingresa un email" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (val) => val!.length < 6 ? "Mínimo 6 caracteres" : null,
                ),
                const SizedBox(height: 30),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleRegister,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text("Crear Cuenta"),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}