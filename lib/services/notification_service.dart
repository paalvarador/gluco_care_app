import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: settings);
  }

  // Función para programar recordatorio de medicina
  static Future<void> scheduleMedication(int id, String name, String dose, DateTime time) async {
    await _notificationsPlugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails:  NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel', 'Medication Reminders',
          importance: Importance.max, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Hora de tu medicina: $name',
      body: 'Dosis: $dose',
      matchDateTimeComponents: DateTimeComponents.time, // Se repite cada día a la misma hora
    );
  }

  static Future<void> scheduleRecurringMedication(int id, String name, String dose, DateTime firstTime, int intervalHours) async {
  // Calculamos cuántas veces al día se toma (ej: 24 / 8 = 3 veces)
  int occurrences = 24 ~/ intervalHours;

  for (int i = 0; i < occurrences; i++) {
    // Calculamos la hora de cada toma sumando el intervalo
    final scheduledTime = firstTime.add(Duration(hours: intervalHours * i));

    await _notificationsPlugin.zonedSchedule(
      id: id + i, // ID único para cada toma
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('med_channel', 'Medicinas'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Hora de tu medicina: $name',
      body: 'Dosis: $dose',
      matchDateTimeComponents: DateTimeComponents.time, // ¡Se repite diario!
    );
  }
}
}