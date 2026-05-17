import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'initial_dashboard.dart';
import 'patient_dashboard.dart';
import 'caregiver_dashboard.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Estado para el indicador de carga

  // Lógica para manejar el inicio de sesión con Google y redirección
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().signInWithGoogle();

      if (user != null) {
        // Consultar Firestore para ver si el usuario ya tiene rol asignado
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (userDoc.exists && userDoc.data()!.containsKey('role')) {
          String role = userDoc.get('role');

          // Si ya tiene rol, lo enviamos al Dashboard que le corresponde
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => role == 'patient'
                  ? const PatientDashboard()
                  : const CaregiverDashboard(),
            ),
            (route) => false,
          );
        } else {
          // Si es un usuario nuevo o sin rol, lo enviamos a elegir su rol
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const InitialDashboard()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al iniciar sesión: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola de nuevo 👋",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blueAccent : Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ingresa tus datos para continuar cuidando de tu salud.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Campo de Email
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Campo de Password
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 30),

                // Botón Ingresar Manual (Email/Password)
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "INGRESAR",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 25),

                const Center(
                  child: Text(
                    "O continúa con",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 25),

                // Botón Google
                OutlinedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleLogo(size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        "Continuar con Google",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Link a Registro
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "¿No tienes cuenta? ",
                        style: TextStyle(color: Colors.grey),
                        children: [
                          TextSpan(
                            text: "Crea una aquí",
                            style: TextStyle(
                              color: isDark ? Colors.blueAccent : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Pantalla de carga (Overlay)
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {

    // Validamos que los campos no estén vacíos
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Iniciar sesión en Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Consultar el rol en Firestore (igual que con Google)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      // Mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Inicio de sesión exitoso! 👋"),
          backgroundColor: Colors.green,
        ),
      );

      // 3. Redirección lógica
      if (userDoc.exists && userDoc.data()!.containsKey('role')) {
        String role = userDoc.get('role');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => role == 'patient'
                ? const PatientDashboard()
                : const CaregiverDashboard(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const InitialDashboard()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Error al ingresar";
      if (e.code == 'user-not-found')
        message = "No existe una cuenta con este email";
      if (e.code == 'wrong-password') message = "Contraseña incorrecta";
      if (e.code == 'invalid-email')
        message = "El formato del email es inválido";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// Logo de Google con colores oficiales, sin dependencias de red
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    // Fondo del botón para que el hueco del logo combine
    final bg = Theme.of(context).cardColor;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter(bg)),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  final Color holeColor;
  const _GoogleLogoPainter(this.holeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    const blue   = Color(0xFF4285F4);
    const red    = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green  = Color(0xFF34A853);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.38;
    final fill = Paint()..style = PaintingStyle.fill;
    final ring = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.8);

    arc.color = red;    canvas.drawArc(ring, -1.57, 1.57, false, arc);
    arc.color = green;  canvas.drawArc(ring,  0.00, 1.57, false, arc);
    arc.color = yellow; canvas.drawArc(ring,  1.57, 1.05, false, arc);
    arc.color = blue;   canvas.drawArc(ring,  2.62, 1.09, false, arc);

    // Brazo horizontal de la "G"
    fill.color = blue;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r * 0.85, r * 0.36),
      fill,
    );

    // Hueco central del donut
    fill.color = holeColor;
    canvas.drawCircle(Offset(cx, cy), r * 0.52, fill);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => old.holeColor != holeColor;
}
