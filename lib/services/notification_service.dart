import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:gluco_care_app/models/notification_prefs.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Channels ──────────────────────────────────────────────────────
  static const _medicationChannel = AndroidNotificationChannel(
    'medication_channel',
    'Medicamentos',
    description: 'Recordatorios para tomar medicamentos',
    importance: Importance.max,
    playSound: true,
  );

  static const _appointmentChannel = AndroidNotificationChannel(
    'appointment_channel',
    'Citas Médicas',
    description: 'Recordatorios de citas con el médico',
    importance: Importance.high,
    playSound: true,
  );

  // ── Notification details ───────────────────────────────────────────
  static const _medicationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_channel',
      'Medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_channel',
      'Medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  static const _appointmentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'appointment_channel',
      'Citas Médicas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
  );

  // ── Init ──────────────────────────────────────────────────────────
  static Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    // Register channels so Android users can customize sound per type
    await androidPlugin?.createNotificationChannel(_medicationChannel);
    await androidPlugin?.createNotificationChannel(_appointmentChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Schedule mode ─────────────────────────────────────────────────
  static Future<AndroidScheduleMode> _scheduleMode() async {
    final canExact = await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        true;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ── Medication: single daily dose ─────────────────────────────────
  static Future<void> scheduleMedication(
    int id,
    String name,
    String dose,
    DateTime time,
  ) async {
    await _plugin.zonedSchedule(
      id: id,
      title: '💊 Hora de tu medicina: $name',
      body: 'Dosis: $dose',
      scheduledDate: _nextInstanceOf(time.hour, time.minute),
      notificationDetails: _medicationDetails,
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule recurring reminders if configured
    final prefs = await NotificationPrefs.load();
    await _scheduleReminderBatch(id, name, dose, time, prefs);
  }

  // ── Medication: multiple daily doses (every N hours) ─────────────
  static Future<void> scheduleRecurringMedication(
    int id,
    String name,
    String dose,
    DateTime firstTime,
    int intervalHours,
  ) async {
    final mode = await _scheduleMode();
    final int occurrences = 24 ~/ intervalHours;
    for (int i = 0; i < occurrences; i++) {
      final time = firstTime.add(Duration(hours: intervalHours * i));
      await _plugin.zonedSchedule(
        id: id + i,
        title: '💊 Hora de tu medicina: $name',
        body: 'Dosis: $dose',
        scheduledDate: _nextInstanceOf(time.hour, time.minute),
        notificationDetails: _medicationDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Recurring reminders only for the first dose slot
    final prefs = await NotificationPrefs.load();
    await _scheduleReminderBatch(id, name, dose, firstTime, prefs);
  }

  // ── Reminder batch (every N minutes after dose time) ─────────────
  // IDs: baseId + 500, baseId + 501, ..., baseId + 509
  static Future<void> _scheduleReminderBatch(
    int baseId,
    String name,
    String dose,
    DateTime doseTime,
    NotificationPrefs prefs,
  ) async {
    // Cancel any previous batch before scheduling new one
    await _cancelReminderBatch(baseId);
    if (!prefs.medicationRecurring) return;

    final mode = await _scheduleMode();
    for (int i = 0; i < prefs.maxRepetitions; i++) {
      final reminderTime = doseTime.add(
        Duration(minutes: prefs.intervalMinutes * (i + 1)),
      );
      await _plugin.zonedSchedule(
        id: baseId + 500 + i,
        title: '⏰ Recordatorio: $name',
        body: 'No olvides tomar tu medicina — Dosis: $dose',
        scheduledDate: _nextInstanceOf(reminderTime.hour, reminderTime.minute),
        notificationDetails: _reminderDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> _cancelReminderBatch(int baseId) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(id: baseId + 500 + i);
    }
  }

  // ── Cancel all notifications for a medication ─────────────────────
  static Future<void> cancelMedication(int id, {int slots = 3}) async {
    for (int i = 0; i < slots; i++) {
      await _plugin.cancel(id: id + i);
    }
    await _cancelReminderBatch(id);
  }

  // ── Appointment: 24h before ───────────────────────────────────────
  // ID range: appointmentBaseId + 20000 to avoid collision with medications
  static Future<void> scheduleAppointment(
    int baseId,
    String doctorName,
    String specialty,
    DateTime appointmentDate,
  ) async {
    final notifTime = appointmentDate.subtract(const Duration(hours: 24));
    if (notifTime.isBefore(DateTime.now())) return; // already past

    await _plugin.zonedSchedule(
      id: baseId + 20000,
      title: '🗓 Cita médica mañana',
      body: 'Tienes cita con $doctorName${specialty.isNotEmpty ? " ($specialty)" : ""}',
      scheduledDate: tz.TZDateTime.from(notifTime, tz.local),
      notificationDetails: _appointmentDetails,
      androidScheduleMode: await _scheduleMode(),
    );
  }

  static Future<void> cancelAppointment(int baseId) async {
    await _plugin.cancel(id: baseId + 20000);
  }

  // ── Helper ────────────────────────────────────────────────────────
  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
