import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'location.dart';
import 'prayer.dart';

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

  static const _adhanShortChannel = AndroidNotificationChannel(
    'alim_adhan_short',
    'Adhan (short)',
    description: 'The call to prayer, about 42 seconds.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('adhan_short'),
  );

  static const _adhanLongChannel = AndroidNotificationChannel(
    'alim_adhan_long',
    'Adhan (full)',
    description: 'The call to prayer, about two and a half minutes.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('adhan_long'),
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
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await android?.createNotificationChannel(_channel);
      await android?.createNotificationChannel(_adhanShortChannel);
      await android?.createNotificationChannel(_adhanLongChannel);
      _ready = true;
    } catch (e) {
      debugPrint('alim: notifications unavailable: $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
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
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
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

  /// The five prayers that can call, in order.
  static const adhanPrayers = <AlimPrayer>[
    AlimPrayer.fajr,
    AlimPrayer.dhuhr,
    AlimPrayer.asr,
    AlimPrayer.maghrib,
    AlimPrayer.isha,
  ];

  /// A stable id for one prayer on one of the next seven days.
  static int adhanSlotId(int dayOffset, AlimPrayer prayer) =>
      100 + dayOffset * 10 + prayer.index;

  static List<AlimPrayer> prayersFromCsv(String? csv) {
    if (csv == null) return const [];
    final wanted = csv.split(',').where((s) => s.isNotEmpty).toSet();
    return [
      for (final prayer in adhanPrayers)
        if (wanted.contains(prayer.name)) prayer,
    ];
  }

  static String prayersToCsv(Iterable<AlimPrayer> prayers) =>
      prayers.map((p) => p.name).join(',');

  static Future<bool> requestExactAlarms() async {
    await init();
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final granted = await android?.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  static AndroidNotificationDetails _adhanDetails(String sound) {
    final long = sound == 'long';
    final channel = long ? _adhanLongChannel : _adhanShortChannel;
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        long ? 'adhan_long' : 'adhan_short',
      ),
      category: AndroidNotificationCategory.alarm,
    );
  }

  /// Writes the next seven days of call to prayer. Exact alarms are used when
  /// Android allows them, otherwise the alarm is left to the system.
  static Future<void> scheduleAdhan({
    required AlimLocation place,
    required String method,
    required bool asrHanafi,
    required String sound,
    required List<AlimPrayer> prayers,
  }) async {
    await init();
    if (prayers.isEmpty) {
      await cancelAdhan();
      return;
    }
    var exact = false;
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      exact = await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      exact = false;
    }
    try {
      for (var id = 100; id <= 999; id++) {
        await _plugin.cancel(id);
      }
      final now = tz.TZDateTime.now(tz.local);
      final today = DateTime.now();
      for (var offset = 0; offset < 7; offset++) {
        final day = DateTime(today.year, today.month, today.day + offset);
        final prayerDay = PrayerDay.forPlace(
          place: place,
          day: day,
          method: method,
          asrHanafi: asrHanafi,
        );
        for (final prayer in prayers) {
          final when = tz.TZDateTime.from(prayerDay.timeOf(prayer), tz.local);
          if (!when.isAfter(now)) continue;
          await _plugin.zonedSchedule(
            adhanSlotId(offset, prayer),
            prayerLabel(prayer),
            'It is time for ${prayerLabel(prayer)}.',
            when,
            NotificationDetails(android: _adhanDetails(sound)),
            androidScheduleMode:
                exact
                    ? AndroidScheduleMode.exactAllowWhileIdle
                    : AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } catch (e) {
      debugPrint('alim: could not schedule the adhan: $e');
    }
  }

  static Future<void> cancelAdhan() async {
    await init();
    try {
      for (var id = 100; id <= 999; id++) {
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }

  /// A sample call, a few seconds from now.
  static Future<void> previewAdhan(String sound) async {
    await init();
    try {
      await _plugin.zonedSchedule(
        99,
        'Adhan preview',
        'This is how the call to prayer will sound.',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        NotificationDetails(android: _adhanDetails(sound)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('alim: could not preview the adhan: $e');
    }
  }
}
