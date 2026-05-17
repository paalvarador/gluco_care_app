import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Inicializar base de datos de zonas horarias con la zona real del dispositivo
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS: pedir permisos directamente en la inicialización
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // v21: initialize usa parámetro nombrado 'settings:'
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 13+: POST_NOTIFICATIONS requiere solicitud en runtime
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // iOS: solicitud explícita por si el diálogo no se mostró en init
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const _androidDetails = AndroidNotificationDetails(
    'medication_channel',
    'Recordatorios de Medicina',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  // Recordatorio diario a hora fija
  static Future<void> scheduleMedication(
    int id,
    String name,
    String dose,
    DateTime time,
  ) async {
    // v21: zonedSchedule usa todos parámetros nombrados
    await _plugin.zonedSchedule(
      id: id,
      title: 'Hora de tu medicina: $name',
      body: 'Dosis: $dose',
      scheduledDate: _nextInstanceOf(time.hour, time.minute),
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Recordatorio recurrente (cada 8h o 12h)
  static Future<void> scheduleRecurringMedication(
    int id,
    String name,
    String dose,
    DateTime firstTime,
    int intervalHours,
  ) async {
    final int occurrences = 24 ~/ intervalHours;
    for (int i = 0; i < occurrences; i++) {
      final time = firstTime.add(Duration(hours: intervalHours * i));
      await _plugin.zonedSchedule(
        id: id + i,
        title: 'Hora de tu medicina: $name',
        body: 'Dosis: $dose',
        scheduledDate: _nextInstanceOf(time.hour, time.minute),
        notificationDetails: _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Cancela todas las notificaciones de un medicamento (máx 3 slots por frecuencia)
  static Future<void> cancelMedication(int id, {int slots = 3}) async {
    for (int i = 0; i < slots; i++) {
      await _plugin.cancel(id: id + i);
    }
  }

  // Retorna el próximo TZDateTime para la hora indicada (hoy si aún no pasó, mañana si ya pasó)
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
