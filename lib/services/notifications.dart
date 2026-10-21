import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'location.dart';
import 'prayer.dart';

class NotificationSchedule {
  const NotificationSchedule({
    required this.count,
    required this.exact,
    this.error,
  });

  final int count;
  final bool exact;
  final String? error;

  bool get ok => error == null && count > 0;
}

class NotificationHealth {
  const NotificationHealth({
    required this.ready,
    required this.enabled,
    required this.exact,
    required this.pending,
  });

  final bool ready;
  final bool enabled;
  final bool exact;
  final List<PendingNotificationRequest> pending;
}

/// One quiet nudge a day. Scheduling reports what actually happened so the
/// interface never claims a reminder is set when Android refused it.
class Notifications {
  Notifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _askedDownloadPermission = false;

  static const adhanHorizonDays = 30;

  /// The icon the system shows in the status bar. It must be a real drawable
  /// resource; the launcher mipmap is not one, and an invalid icon makes every
  /// notification fail silently.
  static const _icon = 'alim_notification';

  static const _dailyChannel = AndroidNotificationChannel(
    'alim_daily_v2',
    'Daily reminder',
    description: 'A gentle nudge to keep the day\'s reading and dhikr.',
    importance: Importance.high,
    playSound: true,
  );

  static const _downloadsChannel = AndroidNotificationChannel(
    'alim_downloads',
    'Downloads',
    description: 'Progress while a surah or a whole voice is being saved.',
    importance: Importance.low,
    playSound: false,
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
    await _setLocalTime();
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
      );
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      // The first daily channel was built silent and cannot be changed after
      // the fact, so it is retired and replaced.
      await android?.deleteNotificationChannel('alim_daily');
      await android?.createNotificationChannel(_dailyChannel);
      await android?.createNotificationChannel(_downloadsChannel);
      await android?.createNotificationChannel(_adhanShortChannel);
      await android?.createNotificationChannel(_adhanLongChannel);
      _ready = true;
    } catch (e) {
      debugPrint('alim: notifications unavailable: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? _android() =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  static DateTime? scheduledAt(PendingNotificationRequest request) {
    final payload = request.payload;
    final parsed = payload == null ? null : DateTime.tryParse(payload);
    return parsed?.toLocal();
  }

  static Future<NotificationHealth> health() async {
    await init();
    final android = _android();
    var enabled = false;
    var exact = false;
    var pending = <PendingNotificationRequest>[];
    try {
      enabled = await android?.areNotificationsEnabled() ?? false;
      exact = await android?.canScheduleExactNotifications() ?? false;
      pending = await _plugin.pendingNotificationRequests();
      pending.sort((a, b) {
        final left = scheduledAt(a);
        final right = scheduledAt(b);
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    } catch (e) {
      debugPrint('alim: could not read notification health: $e');
    }
    return NotificationHealth(
      ready: _ready,
      enabled: enabled,
      exact: exact,
      pending: pending,
    );
  }

  /// The timezone database first, then the platform's zone by name, then a
  /// fixed zone from the current offset, so the clock is never left in UTC.
  static Future<void> _setLocalTime() async {
    try {
      tzdata.initializeTimeZones();
    } catch (_) {
      return;
    }
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      return;
    } catch (_) {}
    try {
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      final sign = hours >= 0 ? '-' : '+';
      tz.setLocalLocation(tz.getLocation('Etc/GMT$sign${hours.abs()}'));
    } catch (_) {}
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

  /// Asked once per session, when a download starts, so its progress may show
  /// in the shade.
  static Future<void> ensureDownloadPermission() async {
    if (_askedDownloadPermission) return;
    _askedDownloadPermission = true;
    await requestPermission();
  }

  static String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static NotificationDetails get _dailyDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'alim_daily_v2',
      'Daily reminder',
      channelDescription:
          'A gentle nudge to keep the day\'s reading and dhikr.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  static Future<bool> _canExact() async {
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<NotificationSchedule> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    await init();
    final exact = await _canExact();
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
        _dailyDetails,
        androidScheduleMode:
            exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: when.toIso8601String(),
      );
      return NotificationSchedule(count: 1, exact: exact);
    } catch (e) {
      debugPrint('alim: could not schedule: $e');
      return NotificationSchedule(count: 0, exact: exact, error: '$e');
    }
  }

  /// A confirmation the moment the reminder is switched on, so the sound and
  /// the look can be heard and seen right away.
  static Future<bool> remindSetNow({
    required int hour,
    required int minute,
  }) async {
    await init();
    try {
      if (await _android()?.areNotificationsEnabled() != true) return false;
      await _plugin.show(
        2,
        'Reminder set',
        'Alim will nudge you every day at ${_clock(hour, minute)}. '
            'This is how it will sound.',
        _dailyDetails,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> scheduleTest({Duration delay = Duration.zero}) async {
    await init();
    try {
      if (await _android()?.areNotificationsEnabled() != true) return false;
      await _plugin.cancel(3);
      if (delay <= Duration.zero) {
        await _plugin.show(
          3,
          'Test notification',
          'Notifications are working. This message is a test from Alim.',
          _dailyDetails,
        );
        return true;
      }
      final when = tz.TZDateTime.now(tz.local).add(delay);
      final exact = await _canExact();
      await _plugin.zonedSchedule(
        3,
        'Test notification',
        'Notifications are working. This message is a test from Alim.',
        when,
        _dailyDetails,
        androidScheduleMode:
            exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: when.toIso8601String(),
      );
      return true;
    } catch (e) {
      debugPrint('alim: could not schedule the test: $e');
      return false;
    }
  }

  static Future<void> cancelDaily() async {
    await init();
    try {
      await _plugin.cancel(1);
    } catch (_) {}
  }

  /// Progress for a running download, kept silent and replaced as it moves.
  static Future<void> downloadProgress({
    required int percent,
    required String body,
  }) async {
    await init();
    try {
      await _plugin.show(
        77,
        'Saving the Qur\'an',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alim_downloads',
            'Downloads',
            channelDescription:
                'Progress while a surah or a whole voice is being saved.',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: 100,
            progress: percent.clamp(0, 100),
            ongoing: true,
            autoCancel: false,
            icon: _icon,
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> hideDownloadProgress() async {
    try {
      await _plugin.cancel(77);
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

  /// A stable id for one prayer on one of the next [adhanHorizonDays] days.
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

  /// Writes the next month of call to prayer. Exact alarms are used when
  /// Android allows them, otherwise the alarm is left to the system.
  static Future<NotificationSchedule> scheduleAdhan({
    required AlimLocation place,
    required String method,
    required bool asrHanafi,
    required String sound,
    required List<AlimPrayer> prayers,
  }) async {
    await init();
    if (prayers.isEmpty) {
      await cancelAdhan();
      return const NotificationSchedule(count: 0, exact: false);
    }
    final exact = await _canExact();
    var count = 0;
    String? error;
    try {
      for (var id = 100; id <= 999; id++) {
        await _plugin.cancel(id);
      }
      final now = tz.TZDateTime.now(tz.local);
      final today = DateTime.now();
      for (var offset = 0; offset < adhanHorizonDays; offset++) {
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
            payload: when.toIso8601String(),
          );
          count++;
        }
      }
    } catch (e) {
      error = '$e';
      count = 0;
      await cancelAdhan();
      debugPrint('alim: could not schedule the adhan: $e');
    }
    return NotificationSchedule(count: count, exact: exact, error: error);
  }

  static Future<void> cancelAdhan() async {
    await init();
    try {
      for (var id = 100; id <= 999; id++) {
        await _plugin.cancel(id);
      }
    } catch (_) {}
  }

  /// A sample call, a few seconds from now: exact when Android allows it, and
  /// straight to the shade otherwise, so it is never silently late.
  static Future<void> previewAdhan(String sound) async {
    await init();
    try {
      if (await _canExact()) {
        final when = tz.TZDateTime.now(
          tz.local,
        ).add(const Duration(seconds: 5));
        await _plugin.zonedSchedule(
          99,
          'Adhan preview',
          'This is how the call to prayer will sound.',
          when,
          NotificationDetails(android: _adhanDetails(sound)),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: when.toIso8601String(),
        );
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      await _plugin.show(
        99,
        'Adhan preview',
        'This is how the call to prayer will sound.',
        NotificationDetails(android: _adhanDetails(sound)),
      );
    } catch (e) {
      debugPrint('alim: could not preview the adhan: $e');
    }
  }
}
