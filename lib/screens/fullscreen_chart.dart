import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gluco_care_app/widgets/health_charts.dart';

class FullscreenChartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allLogs;
  final bool isPremium;

  const FullscreenChartScreen({
    super.key, 
    required this.allLogs, 
    required this.isPremium
  });

  @override
  State<FullscreenChartScreen> createState() => _FullscreenChartScreenState();
}

class _FullscreenChartScreenState extends State<FullscreenChartScreen> {
  @override
  void initState() {
    super.initState();
    // Forzamos el modo horizontal al entrar
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    // Ocultamos la barra de estado para inmersión total
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Al salir, devolvemos el celular a su estado vertical normal
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Análisis Detallado", style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: HealthChart(
            allLogs: widget.allLogs, 
            isPremium: widget.isPremium,
          ),
        ),
      ),
    );
  }
}