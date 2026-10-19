import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'data/store.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'services/location.dart';
import 'services/notifications.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/backdrop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.alim.app.audio',
        androidNotificationChannelName: 'Qur\'an playback',
        androidNotificationChannelDescription:
            'Ayah by ayah, from the reciter you chose',
        androidNotificationOngoing: true,
      );
    } catch (_) {
      // Playback stays in the app; nothing about boot depends on this.
    }
  }
  runApp(const BootRoot());
}

/// The first screen is painted at once, under the crest and the slogan, while
/// the library opens behind it.
class BootRoot extends StatefulWidget {
  const BootRoot({super.key});

  @override
  State<BootRoot> createState() => _BootRootState();
}

class _Ready {
  const _Ready(this.store, this.onboarded);

  final AlimStore store;
  final bool onboarded;
}

class _BootRootState extends State<BootRoot> {
  late final Future<_Ready> _ready = _open();

  Future<_Ready> _open() async {
    final watch = Stopwatch()..start();
    final store = await AlimStore.open();
    var onboarded = false;
    try {
      final raw = await store.kvGet('profile');
      if (raw != null) {
        final name =
            (jsonDecode(raw) as Map<String, dynamic>)['name'] as String? ?? '';
        onboarded = name.trim().isNotEmpty;
      }
    } catch (_) {
      onboarded = false;
    }
    await Notifications.init();
    await Notifications.hideDownloadProgress();
    await _restoreAdhan(store);
    await _restoreReminder(store);
    final left = const Duration(seconds: 3) - watch.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
    return _Ready(store, onboarded);
  }

  /// Keeps the next days of adhan written after a restart, in case Android
  /// dropped the alarms or the phone was off for a while.
  Future<void> _restoreAdhan(AlimStore store) async {
    try {
      final rawProfile = await store.kvGet('profile');
      if (rawProfile == null) return;
      final profile = jsonDecode(rawProfile) as Map<String, dynamic>;
      if (profile['adhanOn'] != true) return;
      final rawPlace = await store.kvGet('location') ?? '';
      final parts = rawPlace.split(',');
      if (parts.length != 2) return;
      final place = AlimLocation(
        double.parse(parts[0]),
        double.parse(parts[1]),
      );
      await Notifications.scheduleAdhan(
        place: place,
        method: profile['prayerMethod'] as String? ?? 'muslimWorldLeague',
        asrHanafi: profile['asrHanafi'] as bool? ?? false,
        sound: profile['adhanSound'] as String? ?? 'short',
        prayers: Notifications.prayersFromCsv(
          profile['adhanPrayers'] as String?,
        ),
      );
    } catch (_) {
      // A missing fix or an odd profile just leaves the adhan quiet.
    }
  }

  /// Writes the daily reminder again on every open, so a lost alarm is
  /// quietly put back in place.
  Future<void> _restoreReminder(AlimStore store) async {
    try {
      final rawProfile = await store.kvGet('profile');
      if (rawProfile == null) return;
      final profile = jsonDecode(rawProfile) as Map<String, dynamic>;
      if (profile['reminderOn'] != true) return;
      await Notifications.scheduleDaily(
        hour: profile['reminderHour'] as int? ?? 20,
        minute: profile['reminderMinute'] as int? ?? 0,
        body: 'Your day has a few open pages. Qur\'an, a hadith, a dhikr.',
      );
    } catch (_) {
      // A reminder that cannot be written leaves the app working.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 450),
      child: FutureBuilder<_Ready>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MaterialApp(
              key: const ValueKey('boot-error'),
              debugShowCheckedModeBanner: false,
              theme: buildAlimTheme(Brightness.light),
              builder: alimBackdropBuilder,
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AlimSpace.lg),
                    child: Text(
                      'Alim could not open its library. Restart the app.\n\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }
          final ready = snapshot.data;
          if (ready == null) {
            return MaterialApp(
              key: const ValueKey('boot-splash'),
              title: 'Alim',
              debugShowCheckedModeBanner: false,
              theme: buildAlimTheme(Brightness.light),
              darkTheme: buildAlimTheme(Brightness.dark),
              themeMode: ThemeMode.system,
              builder: alimBackdropBuilder,
              home: const BootSplash(),
            );
          }
          return ProviderScope(
            key: const ValueKey('boot-ready'),
            overrides: [storeProvider.overrideWithValue(ready.store)],
            child: AlimApp(onboarded: ready.onboarded),
          );
        },
      ),
    );
  }
}

class BootSplash extends StatelessWidget {
  const BootSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: StarLattice(
        rows: 5,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AlimColors.goldSoft.withValues(alpha: dark ? 0.10 : 1),
                  border: Border.all(
                    color: AlimColors.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(
                  Icons.mosque_outlined,
                  size: 44,
                  color: dark ? AlimColors.gold : AlimColors.leaf,
                ),
              ),
              const SizedBox(height: AlimSpace.md),
              Text(
                'Alim',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AlimSpace.xs),
              const Text(
                'Deen and Dunya Unified',
                style: TextStyle(
                  fontFamily: arabicFamily,
                  fontSize: 15,
                  color: AlimColors.gold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: AlimSpace.lg),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlimApp extends ConsumerWidget {
  const AlimApp({super.key, required this.onboarded});

  final bool onboarded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(profileProvider.select((p) => p.themeMode));
    return MaterialApp(
      title: 'Alim',
      debugShowCheckedModeBanner: false,
      theme: buildAlimTheme(Brightness.light),
      darkTheme: buildAlimTheme(Brightness.dark),
      themeMode: switch (mode) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      builder: alimBackdropBuilder,
      home: onboarded ? const ShellScreen() : const OnboardingScreen(),
    );
  }
}
