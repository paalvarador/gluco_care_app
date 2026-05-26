import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:gluco_care_app/models/notification_prefs.dart';

// ── Top-level background handler (Android: app terminated) ────────────
// Only cancels reminder batch — no Firebase (unsafe in background isolate)
@pragma('vm:entry-point')
void onBackgroundNotificationAction(NotificationResponse response) {
  if (response.actionId == 'TAKEN_ACTION') {
    final baseId = int.tryParse(response.payload?.split(':').first ?? '');
    if (baseId != null) {
      final plugin = FlutterLocalNotificationsPlugin();
      for (int i = 0; i < 10; i++) {
        plugin.cancel(id: baseId + 500 + i);
      }
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── iOS category with "Ya tomé" action ───────────────────────────
  static final _medicationCategory = DarwinNotificationCategory(
    'MEDICATION_REMINDER',
    actions: [
      DarwinNotificationAction.plain(
        'TAKEN_ACTION',
        '✓ Ya tomé mi medicina',
        options: {DarwinNotificationActionOption.foreground},
      ),
    ],
  );

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
    iOS: DarwinNotificationDetails(
      presentSound: true,
      categoryIdentifier: 'MEDICATION_REMINDER',
    ),
  );

  // Reminder batch includes the "Ya tomé" action button
  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_channel',
      'Medicamentos',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      actions: [
        AndroidNotificationAction(
          'TAKEN_ACTION',
          '✓ Ya tomé',
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      presentSound: true,
      categoryIdentifier: 'MEDICATION_REMINDER',
    ),
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
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [_medicationCategory],
      // Muestra y suena notificaciones aunque la app esté en foreground
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationAction,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.createNotificationChannel(_medicationChannel);
    await androidPlugin?.createNotificationChannel(_appointmentChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Foreground/background handler — app is running or comes to foreground (iOS)
  static void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'TAKEN_ACTION') {
      final parts = response.payload?.split(':') ?? [];
      if (parts.length >= 2) {
        final baseId = int.tryParse(parts[0]);
        final medicationDocId = parts[1];
        if (baseId != null) {
          cancelTodaysReminders(baseId);
          _logMedicationTaken(medicationDocId);
        }
      }
    }
  }

  static Future<void> _logMedicationTaken(String medicationDocId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Avoid duplicate logs for the same day
      final existing = await FirebaseFirestore.instance
          .collection('medication_logs')
          .where('user_id', isEqualTo: user.uid)
          .where('medication_id', isEqualTo: medicationDocId)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('medication_logs').add({
          'user_id': user.uid,
          'medication_id': medicationDocId,
          'taken_at': FieldValue.serverTimestamp(),
          'date': today,
        });
      }
    } catch (_) {}
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
    DateTime time, {
    String medicationDocId = '',
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: '💊 Hora de tu medicina: $name',
      body: 'Dosis: $dose',
      scheduledDate: _nextInstanceOf(time.hour, time.minute),
      notificationDetails: _medicationDetails,
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$id:$medicationDocId',
    );
    final prefs = await NotificationPrefs.load();
    await _scheduleReminderBatch(id, name, dose, time, prefs, medicationDocId);
  }

  // ── Medication: multiple daily doses (every N hours) ─────────────
  static Future<void> scheduleRecurringMedication(
    int id,
    String name,
    String dose,
    DateTime firstTime,
    int intervalHours, {
    String medicationDocId = '',
  }) async {
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
        payload: '${id + i}:$medicationDocId',
      );
    }
    final prefs = await NotificationPrefs.load();
    await _scheduleReminderBatch(id, name, dose, firstTime, prefs, medicationDocId);
  }

  // ── Reminder batch ────────────────────────────────────────────────
  static Future<void> _scheduleReminderBatch(
    int baseId,
    String name,
    String dose,
    DateTime doseTime,
    NotificationPrefs prefs,
    String medicationDocId,
  ) async {
    await cancelTodaysReminders(baseId);
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
        payload: '$baseId:$medicationDocId',
      );
    }
  }

  // ── Public cancel helpers ─────────────────────────────────────────
  static Future<void> cancelTodaysReminders(int baseId) async {
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(id: baseId + 500 + i);
    }
  }

  static Future<void> cancelMedication(int id, {int slots = 3}) async {
    for (int i = 0; i < slots; i++) {
      await _plugin.cancel(id: id + i);
    }
    await cancelTodaysReminders(id);
  }

  // ── Mark taken from app ───────────────────────────────────────────
  static Future<void> markTaken(int baseId, String medicationDocId) async {
    await cancelTodaysReminders(baseId);
    await _logMedicationTaken(medicationDocId);
  }

  // ── Appointment: advance notification + pre-appointment reminders ─
  static Future<void> scheduleAppointment(
    int baseId,
    String doctorName,
    String specialty,
    DateTime appointmentDate,
  ) async {
    final prefs = await NotificationPrefs.load();
    final now = DateTime.now();
    final doctorLabel = specialty.isNotEmpty ? '$doctorName ($specialty)' : doctorName;

    // Cancel any previously scheduled notifications for this appointment
    await cancelAppointment(baseId);

    // Main advance notification (1h, 12h or 24h before)
    final advanceTime = appointmentDate.subtract(
      Duration(hours: prefs.appointmentAdvanceHours),
    );
    if (advanceTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: baseId + 20000,
        title: '🗓 Cita médica en ${_advanceLabel(prefs.appointmentAdvanceHours)}',
        body: 'Tienes cita con $doctorLabel',
        scheduledDate: tz.TZDateTime.from(advanceTime, tz.local),
        notificationDetails: _appointmentDetails,
        androidScheduleMode: await _scheduleMode(),
      );
    }

    // Pre-appointment reminders every 5 min up to 30 min before
    if (prefs.appointmentReminders) {
      final mode = await _scheduleMode();
      for (int i = 1; i <= 6; i++) {
        final reminderTime = appointmentDate.subtract(Duration(minutes: 5 * i));
        if (reminderTime.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: baseId + 21000 + i,
            title: '⏰ Tu cita en ${5 * i} minutos',
            body: 'Cita con $doctorLabel',
            scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
            notificationDetails: _appointmentDetails,
            androidScheduleMode: mode,
          );
        }
      }
    }
  }

  static Future<void> cancelAppointment(int baseId) async {
    await _plugin.cancel(id: baseId + 20000);
    for (int i = 1; i <= 6; i++) {
      await _plugin.cancel(id: baseId + 21000 + i);
    }
  }

  static String _advanceLabel(int hours) {
    switch (hours) {
      case 1:  return '1 hora';
      case 12: return '12 horas';
      default: return '24 horas';
    }
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
