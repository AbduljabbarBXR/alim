import 'dart:io';

import 'package:alim/data/store.dart';
import 'package:alim/screens/mushaf.dart';
import 'package:alim/screens/onboarding.dart';
import 'package:alim/screens/quran_reader.dart';
import 'package:alim/screens/settings.dart';
import 'package:alim/screens/shell.dart';
import 'package:alim/screens/stories.dart';
import 'package:alim/state.dart';
import 'package:alim/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlimStore store;
  late Directory temp;

  // A Monday, so the rotating task is the Monday one and the plan is stable.
  final monday = DateTime(2026, 1, 5, 9);

  setUpAll(() async {
    sqfliteFfiInit();
    // Widget tests run in a fake-async zone: the isolate-based factory would
    // never complete there, so the whole suite talks to sqlite in-process.
    databaseFactory = databaseFactoryFfiNoIsolate;
    temp = await Directory.systemTemp.createTemp('alim_widget_test');
    store = await AlimStore.open(overridePath: temp.path);
  });

  tearDownAll(() async {
    await store.close();
    await temp.delete(recursive: true);
  });

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(monday),
    ],
    child: MaterialApp(theme: buildAlimTheme(Brightness.light), home: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> dragUp(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
    await settle(tester);
  }

  /// Scrolls the first list until the text is built, the way a thumb would.
  Future<void> scrollTo(
    WidgetTester tester,
    String text, {
    int maxDrags = 8,
  }) async {
    for (var i = 0; i < maxDrags; i++) {
      if (find.text(text).evaluate().isNotEmpty) return;
      await dragUp(tester, 300);
    }
    expect(find.text(text), findsOneWidget);
  }

  testWidgets('the shell puts the day\'s plan first', (tester) async {
    await tester.pumpWidget(wrap(const ShellScreen()));
    await settle(tester);

    expect(find.text('Today\'s plan'), findsOneWidget);
    expect(find.text('Read 5 ayat'), findsOneWidget);
    expect(find.textContaining('day streak'), findsOneWidget);

    await scrollTo(tester, 'Verse of the day');
    await scrollTo(tester, 'Hadith of the day');
  });

  testWidgets('a manual task can be ticked and counts toward the day', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ShellScreen()));
    await settle(tester);

    await dragUp(tester, 260);
    expect(find.text('Review Surah Al-Ikhlas'), findsOneWidget);
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await settle(tester);

    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('the reader counts an ayah and remembers the place', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const QuranReaderScreen(surah: 1)));
    await settle(tester);

    expect(find.text('Al-Faatiha 1:1'), findsOneWidget);
    expect(find.text('Al-Faatiha 1:2'), findsOneWidget);

    await tester.tap(find.text('Al-Faatiha 1:1'));
    await settle(tester);
    expect(find.text('Read today'), findsOneWidget);
    expect(find.text('Mark as last read'), findsOneWidget);

    final read = await store.kvGet('read_set_${AlimStore.todayKey(monday)}');
    expect(read, isNotNull);
    expect(read!.split(','), contains('1'));
    expect(await store.lastRead(), isNull);

    await tester.tap(find.text('Mark as last read'));
    await settle(tester);
    expect(await store.lastRead(), 1);
  });

  testWidgets('the mushaf opens on the page of the day', (tester) async {
    await tester.pumpWidget(wrap(const MushafScreen(initialAyah: 1)));
    await settle(tester);

    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('Al-Faatiha'), findsOneWidget);
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('a story shows where it sits in the sunnah', (tester) async {
    final stories = await store.stories();
    final sourced = stories.firstWhere((s) => s.hadithId != null);
    await tester.pumpWidget(wrap(StoryDetailScreen(story: sourced)));
    await settle(tester);
    await scrollTo(tester, 'In the Sunnah', maxDrags: 20);

    final unsourced = stories.firstWhere((s) => s.hadithId == null);
    await tester.pumpWidget(wrap(StoryDetailScreen(story: unsourced)));
    await settle(tester);
    expect(find.text('In the Sunnah'), findsNothing);
  });

  testWidgets('choosing a translation changes what the reader shows', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await settle(tester);

    await scrollTo(tester, 'Translation');
    await tester.tap(find.text('Translation'));
    await settle(tester);

    expect(find.text('The Meaning of the Glorious Koran'), findsOneWidget);
    await tester.tap(find.text('The Meaning of the Glorious Koran'));
    await settle(tester);

    final saved = await store.kvGet('profile');
    expect(saved, contains('"translation":"pickthall"'));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const QuranReaderScreen(surah: 1),
      ),
    );
    await settle(tester);
    expect(
      find.text('In the name of Allah, the Beneficent, the Merciful.'),
      findsOneWidget,
    );
  });

  testWidgets('onboarding walks name, goal and reminder into a saved profile', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const OnboardingScreen()));
    await tester.pump();

    expect(find.text('Alim'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Yusuf');
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('A daily portion of Qur\'an'), findsOneWidget);
    await tester.tap(find.text('10 ayat'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('One quiet reminder a day'), findsOneWidget);
    await tester.tap(find.text('Begin'));
    await settle(tester);

    expect(find.text('Today\'s plan'), findsOneWidget);
    final saved = await store.kvGet('profile');
    expect(saved, contains('Yusuf'));
    expect(saved, contains('"versesGoal":10'));
  });
}
