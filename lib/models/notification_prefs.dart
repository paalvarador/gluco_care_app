import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefs {
  final bool medicationRecurring;
  final int intervalMinutes;  // 1, 2, 5, 10
  final int maxRepetitions;   // 3, 5, 10

  static const _keyRecurring = 'notif_medication_recurring';
  static const _keyInterval  = 'notif_interval_minutes';
  static const _keyMax       = 'notif_max_repetitions';

  const NotificationPrefs({
    this.medicationRecurring = false,
    this.intervalMinutes = 5,
    this.maxRepetitions = 3,
  });

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      medicationRecurring: prefs.getBool(_keyRecurring) ?? false,
      intervalMinutes: prefs.getInt(_keyInterval) ?? 5,
      maxRepetitions: prefs.getInt(_keyMax) ?? 3,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecurring, medicationRecurring);
    await prefs.setInt(_keyInterval, intervalMinutes);
    await prefs.setInt(_keyMax, maxRepetitions);
  }

  NotificationPrefs copyWith({
    bool? medicationRecurring,
    int? intervalMinutes,
    int? maxRepetitions,
  }) => NotificationPrefs(
    medicationRecurring: medicationRecurring ?? this.medicationRecurring,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    maxRepetitions: maxRepetitions ?? this.maxRepetitions,
  );
}
