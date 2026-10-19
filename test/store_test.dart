import 'dart:io';

import 'package:alim/data/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlimStore store;
  late Directory temp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('alim_store_test');
    store = await AlimStore.open(overridePath: temp.path);
  });

  tearDownAll(() async {
    await store.close();
    await temp.delete(recursive: true);
  });

  group('the Qur\'an in the database', () {
    test('114 surahs and 6236 ayat', () async {
      final surahs = await store.surahs();
      expect(surahs, hasLength(114));
      expect(surahs.first.number, 1);
      expect(surahs.first.name, 'Al-Faatiha');
      expect(surahs.first.ayat, 7);
      expect(surahs.first.revelation, 'Mecca');
      final total = surahs.map((s) => s.ayat).fold<int>(0, (a, b) => a + b);
      expect(total, 6236);
    });

    test('a surah arrives whole, with both languages', () async {
      final ayat = await store.ayatOf(1);
      expect(ayat, hasLength(7));
      expect(ayat.first.textAr, contains('ٱللَّهِ'));
      expect(ayat.first.textEn.toLowerCase(), contains('merciful'));
      expect(ayat.last.surah, 1);
      expect(ayat.last.ayah, 7);
    });

    test('a known ayah reads correctly', () async {
      final kursi = await store.ayahAt(2, 255);
      expect(kursi.number, 262);
      expect(kursi.textEn, contains('Allah'));
      final surah = await store.surahOfAyah(kursi.number);
      expect(surah.number, 2);
      final same = await store.ayah(kursi.number);
      expect(same.ayah, 255);
    });

    test('Arabic search folds diacritics through the stored index', () async {
      final results = await store.searchAyat('الرحمن');
      expect(results, isNotEmpty);
      final needle = normalizeArabic('الرحمن');
      for (final a in results) {
        expect(normalizeArabic(a.textAr), contains(needle));
      }
    });

    test('English search matches the translation', () async {
      final results = await store.searchAyat('charity');
      expect(results, isNotEmpty);
      for (final a in results.take(5)) {
        expect(a.textEn.toLowerCase(), contains('charity'));
      }
    });

    test('four translations, Saheeh International first', () async {
      final items = await store.translations();
      expect(items.map((t) => t.slug).toList(), [
        'sahih',
        'pickthall',
        'yusufali',
        'hilali',
      ]);
      expect(items.first.translator, 'Saheeh International');
      for (final t in items) {
        expect(t.source, 'Tanzil.net');
      }
    });

    test('the reading follows the chosen translation', () async {
      final sahih = await store.ayah(1);
      expect(sahih.textEn, contains('Entirely Merciful'));
      final pickthall = await store.ayah(1, translation: 'pickthall');
      expect(pickthall.textEn, contains('Beneficent'));
      final whole = await store.ayatOf(1, translation: 'yusufali');
      expect(whole, hasLength(7));
      expect(whole.every((a) => a.textEn.isNotEmpty), isTrue);
    });

    test('search speaks the chosen translation', () async {
      final inSahih = await store.searchAyat('entirely merciful');
      expect(inSahih, isNotEmpty);
      final inPickthall = await store.searchAyat(
        'entirely merciful',
        translation: 'pickthall',
      );
      expect(inPickthall, isEmpty);
      final ali = await store.searchAyat(
        'guard against evil',
        translation: 'yusufali',
      );
      expect(ali, isNotEmpty);
      for (final a in ali.take(5)) {
        expect(a.textEn.toLowerCase(), contains('guard against evil'));
      }
    });

    test('an unknown translation falls back to the default', () async {
      final a = await store.ayah(1, translation: 'not-a-translation');
      expect(a.textEn, contains('Entirely Merciful'));
    });
  });

  group('the hadith in the database', () {
    test('the four authentic collections line up', () async {
      final collections = await store.hadithCollections();
      expect(collections.map((c) => c.id).toList(), [
        'bukhari',
        'muslim',
        'nawawi',
        'qudsi',
      ]);
      expect(collections[0].count, greaterThan(7000));
      expect(collections[2].count, 42);
      expect(collections[3].count, 40);
    });

    test('a book lists its chapters and every hadith is reachable', () async {
      final books = await store.hadithBooks('nawawi');
      expect(books, hasLength(1));
      final first = books.single;
      expect(first.title, 'Forty Hadith of an-Nawawi');
      expect(first.count, 42);
      final items = await store.hadithsOfBook('nawawi', first.number);
      expect(items, hasLength(first.count));
      expect(items.first.textEn, isNotEmpty);
      expect(items.first.textAr, isNotEmpty);
    });

    test('the short hadith pool supplies the daily pick', () async {
      final count = await store.shortHadithCount();
      expect(count, greaterThan(500));
      final pick = await store.shortHadithAt(3);
      expect(pick.textEn, isNotEmpty);
      expect(pick.collection, isNotEmpty);
    });
  });

  group('searching the hadith', () {
    test('a topic finds passages and chapters', () async {
      final passages = await store.searchHadith('prayer', limit: 20);
      expect(passages, isNotEmpty);
      for (final h in passages.take(5)) {
        expect(h.textEn.toLowerCase(), contains('prayer'));
      }
      final books = await store.searchHadithBooks('prayer');
      expect(books, isNotEmpty);
      for (final b in books) {
        expect(b.title.toLowerCase(), contains('prayer'));
      }
    });

    test('Arabic finds a passage without its diacritics', () async {
      final passages = await store.searchHadith('الصلاة', limit: 5);
      expect(passages, isNotEmpty);
    });
  });

  group('pages and juz', () {
    test('the mushaf has 604 pages', () async {
      expect(await store.pageCount(), 604);
    });

    test('a page arrives in order and a place maps back to its page', () async {
      final ayat = await store.ayatOfPage(1);
      expect(ayat, isNotEmpty);
      expect(ayat.first.surah, 1);
      expect(ayat.first.ayah, 1);
      expect(await store.pageOfAyah(1), 1);
      final kursi = await store.ayahAt(2, 255);
      expect(await store.pageOfAyah(kursi.number), kursi.page);
    });

    test('thirty juz in order', () async {
      final starts = await store.juzStarts();
      expect(starts, hasLength(30));
      expect(starts.first, 1);
      expect(starts, orderedEquals(List.of(starts)..sort()));
    });
  });

  group('the stories', () {
    test('forty-six stories, each with a body and a lesson', () async {
      final stories = await store.stories();
      expect(stories, hasLength(46));
      for (final s in stories) {
        expect(s.paragraphs, isNotEmpty);
        expect(s.lesson, isNotEmpty);
        expect(s.minutes, greaterThan(0));
      }
      expect(stories.where((s) => s.ayahNumber != null), hasLength(44));

      final sourced = stories.where((s) => s.hadithId != null).toList();
      expect(sourced, hasLength(12));
      for (final s in sourced) {
        expect(s.hadithRef, isNotNull);
        expect(s.hadithRef, contains('no.'));
        final source = await store.hadithById(s.hadithId!);
        expect(source.textEn, isNotEmpty);
      }

      expect(stories.where((s) => s.category == 'Prophets'), hasLength(25));
      expect(stories.where((s) => s.category == 'Companions'), hasLength(12));
      expect(stories.where((s) => s.category == 'Chosen'), hasLength(9));
    });
  });

  group('the person\'s own record', () {
    const date = '2030-01-01';

    test('a fresh day is empty', () async {
      final log = await store.day(date);
      expect(log.verses, 0);
      expect(log.tasks, isEmpty);
      expect(log.gratitude, '');
    });

    test('activity accumulates on the day', () async {
      await store.addVerses(date, 3);
      await store.addVerses(date, 2);
      await store.addHadiths(date, 1);
      await store.addStories(date, 1);
      await store.addDhikr(date, 100);
      await store.addXp(date, 80);
      await store.setTaskDone(date, 'rot-mon', true);
      await store.setTaskDone(date, 'gratitude', true);
      await store.setTaskDone(date, 'gratitude', false);
      await store.setGratitude(date, 'rain on the roof');

      final log = await store.day(date);
      expect(log.verses, 5);
      expect(log.hadiths, 1);
      expect(log.stories, 1);
      expect(log.dhikr, 100);
      expect(log.xp, 80);
      expect(log.tasks, {'rot-mon'});
      expect(log.gratitude, 'rain on the roof');
    });

    test('the place in the mushaf is remembered', () async {
      await store.setLastRead(262);
      expect(await store.lastRead(), 262);
    });

    test('bookmarks toggle', () async {
      expect(await store.isBookmarked('ayah', 262), isFalse);
      await store.toggleBookmark('ayah', 262, 'Al-Baqara 2:255');
      expect(await store.isBookmarked('ayah', 262), isTrue);
      final marks = await store.bookmarks(kind: 'ayah');
      expect(marks.map((b) => b.ref), contains(262));
      await store.toggleBookmark('ayah', 262, 'Al-Baqara 2:255');
      expect(await store.isBookmarked('ayah', 262), isFalse);
      expect(await store.bookmarks(kind: 'ayah'), isEmpty);
    });

    test('tasks are added, ticked and deleted', () async {
      final id = await store.addTodo('Buy dates for iftar', due: '2030-01-02');
      var todos = await store.todos();
      expect(todos, hasLength(1));
      expect(todos.single.done, isFalse);
      expect(todos.single.due, '2030-01-02');
      await store.toggleTodo(id);
      todos = await store.todos();
      expect(todos.single.done, isTrue);
      await store.deleteTodo(id);
      expect(await store.todos(), isEmpty);
    });

    test('the journey adds up', () async {
      final stats = await store.stats(now: DateTime(2030, 1, 1));
      expect(stats.verses, greaterThanOrEqualTo(5));
      expect(stats.hadiths, greaterThanOrEqualTo(1));
      expect(stats.stories, greaterThanOrEqualTo(1));
      expect(stats.dhikr, greaterThanOrEqualTo(100));
      expect(stats.xp, greaterThanOrEqualTo(80));
      expect(stats.activeDays, greaterThanOrEqualTo(1));
      expect(stats.streak, greaterThanOrEqualTo(1));
      expect(stats.bestStreak, greaterThanOrEqualTo(1));
    });

    test('erasing gives back a clean slate', () async {
      await store.eraseUserData();
      final log = await store.day(date);
      expect(log.verses, 0);
      expect(await store.lastRead(), isNull);
      expect(await store.bookmarks(), isEmpty);
      expect(await store.todos(), isEmpty);
    });
  });

  test('a new library lands without wiping the record', () async {
    final dir = await Directory.systemTemp.createTemp('alim_upgrade_test');
    final before = await AlimStore.open(overridePath: dir.path);
    await before.kvSet('marker', 'kept');
    await before.setLastRead(262);
    await before.close();

    final raw = await databaseFactory.openDatabase(p.join(dir.path, 'alim.db'));
    await raw.update(
      'meta',
      {'value': '1'},
      where: 'key = ?',
      whereArgs: ['db_version'],
    );
    await raw.close();

    final after = await AlimStore.open(overridePath: dir.path);
    expect(await after.kvGet('marker'), 'kept');
    expect(await after.lastRead(), 262);
    expect(await after.stories(), hasLength(46));
    await after.close();
    await dir.delete(recursive: true);
  });
}
