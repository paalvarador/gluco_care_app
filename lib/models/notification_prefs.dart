import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefs {
  final bool medicationRecurring;
  final int intervalMinutes;       // 1, 2, 5, 10
  final int maxRepetitions;        // 3, 5, 10
  final int appointmentAdvanceHours; // 1, 12, 24
  final bool appointmentReminders;   // recordatorios cada 5 min antes de la cita

  static const _keyRecurring      = 'notif_medication_recurring';
  static const _keyInterval       = 'notif_interval_minutes';
  static const _keyMax            = 'notif_max_repetitions';
  static const _keyApptAdvance    = 'notif_appt_advance_hours';
  static const _keyApptReminders  = 'notif_appt_reminders';

  const NotificationPrefs({
    this.medicationRecurring = false,
    this.intervalMinutes = 5,
    this.maxRepetitions = 3,
    this.appointmentAdvanceHours = 24,
    this.appointmentReminders = true,
  });

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      medicationRecurring:      prefs.getBool(_keyRecurring)     ?? false,
      intervalMinutes:          prefs.getInt(_keyInterval)        ?? 5,
      maxRepetitions:           prefs.getInt(_keyMax)             ?? 3,
      appointmentAdvanceHours:  prefs.getInt(_keyApptAdvance)     ?? 24,
      appointmentReminders:     prefs.getBool(_keyApptReminders)  ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecurring,     medicationRecurring);
    await prefs.setInt(_keyInterval,       intervalMinutes);
    await prefs.setInt(_keyMax,            maxRepetitions);
    await prefs.setInt(_keyApptAdvance,    appointmentAdvanceHours);
    await prefs.setBool(_keyApptReminders, appointmentReminders);
  }

  NotificationPrefs copyWith({
    bool? medicationRecurring,
    int? intervalMinutes,
    int? maxRepetitions,
    int? appointmentAdvanceHours,
    bool? appointmentReminders,
  }) => NotificationPrefs(
    medicationRecurring:     medicationRecurring     ?? this.medicationRecurring,
    intervalMinutes:         intervalMinutes         ?? this.intervalMinutes,
    maxRepetitions:          maxRepetitions          ?? this.maxRepetitions,
    appointmentAdvanceHours: appointmentAdvanceHours ?? this.appointmentAdvanceHours,
    appointmentReminders:    appointmentReminders    ?? this.appointmentReminders,
  );
}
