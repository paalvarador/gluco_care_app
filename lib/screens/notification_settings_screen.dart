import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gluco_care_app/models/notification_prefs.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPrefs _prefs = const NotificationPrefs();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await NotificationPrefs.load();
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _save(NotificationPrefs updated) async {
    await updated.save();
    setState(() => _prefs = updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Recordatorio recurrente ─────────────────────────
                _sectionHeader('💊 Medicamentos', isDark),
                const SizedBox(height: 8),
                _card(
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Recordatorio recurrente',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Vuelve a notificar si no tomaste la medicina',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _prefs.medicationRecurring,
                        activeThumbColor: color,
                        onChanged: (v) =>
                            _save(_prefs.copyWith(medicationRecurring: v)),
                      ),
                      if (_prefs.medicationRecurring) ...[
                        const Divider(),
                        const SizedBox(height: 4),
                        Text(
                          'Intervalo entre recordatorios',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _chipSelector(
                          options: const [1, 2, 5, 10],
                          labels: const ['1 min', '2 min', '5 min', '10 min'],
                          selected: _prefs.intervalMinutes,
                          color: color,
                          onSelected: (v) =>
                              _save(_prefs.copyWith(intervalMinutes: v)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Máximo de recordatorios',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _chipSelector(
                          options: const [3, 5, 10],
                          labels: const ['3 veces', '5 veces', '10 veces'],
                          selected: _prefs.maxRepetitions,
                          color: color,
                          onSelected: (v) =>
                              _save(_prefs.copyWith(maxRepetitions: v)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: Colors.amber.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ejemplo: con 5 min y 3 veces, recibirás recordatorios a los 5, 10 y 15 minutos después de la hora de tu medicina.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Citas médicas ───────────────────────────────────
                _sectionHeader('🗓 Citas médicas', isDark),
                const SizedBox(height: 8),
                _card(
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aviso anticipado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _chipSelector(
                        options: const [1, 12, 24],
                        labels: const ['1 hora antes', '12 horas antes', '24 horas antes'],
                        selected: _prefs.appointmentAdvanceHours,
                        color: color,
                        onSelected: (v) =>
                            _save(_prefs.copyWith(appointmentAdvanceHours: v)),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Recordatorios antes de la cita',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Recibirás notificaciones cada 5 minutos durante los 30 minutos previos a tu cita',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _prefs.appointmentReminders,
                        activeThumbColor: color,
                        onChanged: (v) =>
                            _save(_prefs.copyWith(appointmentReminders: v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Info sobre sonidos ──────────────────────────────
                _sectionHeader('🔔 Sonidos', isDark),
                const SizedBox(height: 8),
                _card(
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GlucoCare usa sonidos del sistema para las notificaciones. '
                        'Puedes personalizar el sonido de cada tipo de notificación '
                        'desde la configuración de tu dispositivo:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (Platform.isAndroid) ...[
                        _soundStep('1.', 'Abre Ajustes de tu teléfono'),
                        _soundStep('2.', 'Aplicaciones → GlucoCare'),
                        _soundStep('3.', 'Notificaciones'),
                        _soundStep('4.',
                            'Elige "Medicamentos" o "Citas Médicas" y cambia el sonido'),
                      ] else ...[
                        _soundStep('1.', 'Abre Ajustes de tu iPhone'),
                        _soundStep('2.', 'Notificaciones → GlucoCare'),
                        _soundStep('3.', 'Sonidos → ajusta según prefieras'),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) => Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      );

  Widget _card(bool isDark, {required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: child,
      );

  Widget _chipSelector({
    required List<int> options,
    required List<String> labels,
    required int selected,
    required Color color,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selected;
        return ChoiceChip(
          label: Text(labels[i]),
          selected: isSelected,
          selectedColor: color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          onSelected: (_) => onSelected(options[i]),
        );
      }),
    );
  }

  Widget _soundStep(String number, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
