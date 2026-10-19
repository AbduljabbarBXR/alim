import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/store.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'services/notifications.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: AlimApp(onboarded: onboarded),
    ),
  );
}

class AlimApp extends ConsumerWidget {
  const AlimApp({super.key, required this.onboarded});

  final bool onboarded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(profileProvider.select((p) => p.darkMode));
    return MaterialApp(
      title: 'Alim',
      debugShowCheckedModeBanner: false,
      theme: buildAlimTheme(Brightness.light),
      darkTheme: buildAlimTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: onboarded ? const ShellScreen() : const OnboardingScreen(),
    );
  }
}
