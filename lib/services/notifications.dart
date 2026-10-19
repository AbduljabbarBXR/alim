import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One quiet nudge a day. Everything is best-effort: if the platform refuses
/// the alarm the app still works, it simply stays silent.
class Notifications {
  Notifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationChannel(
    'alim_daily',
    'Daily reminder',
    description: 'A gentle nudge to keep the day\'s reading and dhikr.',
    importance: Importance.defaultImportance,
  );

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC scheduling rather than not scheduling at all.
    }
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('alim: notifications unavailable: $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    await init();
    try {
      await _plugin.cancel(1);
      final now = tz.TZDateTime.now(tz.local);
      var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        1,
        'Alim',
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'alim_daily',
            'Daily reminder',
            channelDescription:
                'A gentle nudge to keep the day\'s reading and dhikr.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('alim: could not schedule: $e');
    }
  }

  static Future<void> cancelDaily() async {
    await init();
    try {
      await _plugin.cancel(1);
    } catch (_) {}
  }
}
