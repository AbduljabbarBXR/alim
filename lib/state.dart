import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/store.dart';
import 'models.dart';
import 'services/daily.dart';
import 'services/location.dart';
import 'services/prayer.dart';

/// The store is built in main() and injected here.
final storeProvider = Provider<AlimStore>(
  (ref) => throw UnimplementedError('storeProvider must be overridden'),
);

/// Bumped after every change to the person's own data. Everything that reads
/// the daily log, bookmarks, todos or stats watches this and refetches.
final revisionProvider = StateProvider<int>((ref) => 0);

/// The wall clock, refreshed just after midnight so the day rolls over
/// without a restart. Tests override it with a fixed date.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1));
  final timer = Timer(
    midnight.difference(now) + const Duration(seconds: 5),
    () => ref.invalidateSelf(),
  );
  ref.onDispose(timer.cancel);
  return now;
});

String dayKey(DateTime d) => AlimStore.todayKey(d);

// ------------------------------------------------------------------ profile

class ProfileNotifier extends StateNotifier<Profile> {
  ProfileNotifier(this._store) : super(const Profile()) {
    _restore();
  }

  final AlimStore _store;
  static const _key = 'profile';

  Future<void> _restore() async {
    final raw = await _store.kvGet(_key);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      state = Profile(
        name: m['name'] as String? ?? '',
        versesGoal: m['versesGoal'] as int? ?? 5,
        translationOn: m['translationOn'] as bool? ?? true,
        arabicScale: (m['arabicScale'] as num?)?.toDouble() ?? 1.0,
        darkMode: m['darkMode'] as bool? ?? false,
        reminderHour: m['reminderHour'] as int? ?? 20,
        reminderMinute: m['reminderMinute'] as int? ?? 0,
        reminderOn: m['reminderOn'] as bool? ?? false,
        prayerMethod: m['prayerMethod'] as String? ?? 'muslimWorldLeague',
        asrHanafi: m['asrHanafi'] as bool? ?? false,
      );
    } catch (_) {
      // A corrupt profile is not worth crashing over; defaults stand.
    }
  }

  bool get onboardingDone => state.name.trim().isNotEmpty;

  Future<void> save(Profile next) async {
    state = next;
    await _store.kvSet(_key, jsonEncode({
      'name': next.name,
      'versesGoal': next.versesGoal,
      'translationOn': next.translationOn,
      'arabicScale': next.arabicScale,
      'darkMode': next.darkMode,
      'reminderHour': next.reminderHour,
      'reminderMinute': next.reminderMinute,
      'reminderOn': next.reminderOn,
      'prayerMethod': next.prayerMethod,
      'asrHanafi': next.asrHanafi,
    }));
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, Profile>((ref) {
  return ProfileNotifier(ref.watch(storeProvider));
});

// ---------------------------------------------------------------- content

final surahsProvider = FutureProvider<List<Surah>>((ref) {
  return ref.watch(storeProvider).surahs();
});

class SurahView {
  const SurahView(this.surah, this.ayat);

  final Surah surah;
  final List<Ayah> ayat;
}

final surahViewProvider =
    FutureProvider.family<SurahView, int>((ref, number) async {
  final store = ref.watch(storeProvider);
  return SurahView(await store.surah(number), await store.ayatOf(number));
});

final searchProvider =
    FutureProvider.family<List<Ayah>, String>((ref, query) async {
  if (query.trim().length < 2) return const [];
  return ref.watch(storeProvider).searchAyat(query);
});

final juzStartsProvider = FutureProvider<List<int>>((ref) {
  return ref.watch(storeProvider).juzStarts();
});

final pageCountProvider = FutureProvider<int>((ref) {
  return ref.watch(storeProvider).pageCount();
});

final pageAyatProvider =
    FutureProvider.family<List<Ayah>, int>((ref, page) {
  return ref.watch(storeProvider).ayatOfPage(page);
});

final ayahProvider = FutureProvider.family<Ayah, int>((ref, number) {
  return ref.watch(storeProvider).ayah(number);
});

final ayahAtProvider =
    FutureProvider.family<Ayah, (int, int)>((ref, ref2) async {
  final store = ref.watch(storeProvider);
  final rows = await store.ayatOf(ref2.$1);
  return rows.firstWhere((a) => a.ayah == ref2.$2);
});

final hadithCollectionsProvider = FutureProvider<List<HadithCollection>>((ref) {
  return ref.watch(storeProvider).hadithCollections();
});

final hadithBooksProvider =
    FutureProvider.family<List<HadithBook>, String>((ref, collection) {
  return ref.watch(storeProvider).hadithBooks(collection);
});

class HadithPage {
  const HadithPage(this.collection, this.book, this.offset, this.items);

  final String collection;
  final int book;
  final int offset;
  final List<Hadith> items;
}

final hadithPageProvider =
    FutureProvider.family<List<Hadith>, (String, int, int)>((ref, args) {
  return ref
      .watch(storeProvider)
      .hadithsOfBook(args.$1, args.$2, offset: args.$3);
});

final hadithByIdProvider = FutureProvider.family<Hadith, int>((ref, id) {
  return ref.watch(storeProvider).hadithById(id);
});

final hadithSearchProvider =
    FutureProvider.family<List<Hadith>, String>((ref, query) {
  return ref.watch(storeProvider).searchHadith(query, limit: 60);
});

final hadithBookSearchProvider =
    FutureProvider.family<List<HadithBook>, String>((ref, query) {
  return ref.watch(storeProvider).searchHadithBooks(query);
});

final shortHadithCountProvider = FutureProvider<int>((ref) {
  return ref.watch(storeProvider).shortHadithCount();
});

final hadithOfDayProvider = FutureProvider<Hadith>((ref) async {
  final store = ref.watch(storeProvider);
  final count = await store.shortHadithCount();
  final n = dayNumber(ref.watch(todayProvider));
  return store.shortHadithAt(n % count);
});

final storiesProvider = FutureProvider<List<Story>>((ref) {
  return ref.watch(storeProvider).stories();
});

final storyProvider = FutureProvider.family<Story, int>((ref, id) {
  return ref.watch(storeProvider).story(id);
});

final verseOfDayProvider = FutureProvider<Ayah>((ref) {
  final ref2 = verseRefOfDay(ref.watch(todayProvider));
  final store = ref.watch(storeProvider);
  return store.ayahAt(ref2[0], ref2[1]);
});

final surahOfAyahProvider = FutureProvider.family<Surah, int>((ref, ayah) {
  return ref.watch(storeProvider).surahOfAyah(ayah);
});

/// The remembered place, when one was set. Null means prayer times and the
/// qibla have nothing to work from yet.
final locationProvider = FutureProvider<AlimLocation?>((ref) async {
  ref.watch(revisionProvider);
  final raw = await ref.watch(storeProvider).kvGet('location');
  if (raw == null) return null;
  final parts = raw.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lng = double.tryParse(parts[1]);
  if (lat == null || lng == null) return null;
  return AlimLocation(lat, lng);
});

final prayerScheduleProvider = FutureProvider<PrayerDay?>((ref) async {
  final place = await ref.watch(locationProvider.future);
  if (place == null) return null;
  final profile = ref.watch(profileProvider);
  return PrayerDay.forPlace(
    place: place,
    day: ref.watch(todayProvider),
    method: profile.prayerMethod,
    asrHanafi: profile.asrHanafi,
  );
});

// -------------------------------------------------------------- user data

final lastReadProvider = FutureProvider<int?>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).lastRead();
});

final dayProvider = FutureProvider.family<DayLog, String>((ref, date) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).day(date);
});

final todayLogProvider = FutureProvider<DayLog>((ref) {
  ref.watch(revisionProvider);
  final date = dayKey(ref.watch(todayProvider));
  return ref.watch(storeProvider).day(date);
});

final todayTasksProvider = FutureProvider<List<DailyTask>>((ref) {
  final profile = ref.watch(profileProvider);
  return buildDailyTasks(
    date: ref.watch(todayProvider),
    versesGoal: profile.versesGoal,
  );
});

final statsProvider = FutureProvider<JourneyStats>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).stats(now: ref.watch(todayProvider));
});

final weeklyProvider = FutureProvider<List<int>>((ref) {
  ref.watch(revisionProvider);
  return ref
      .watch(storeProvider)
      .versesLastDays(7, now: ref.watch(todayProvider));
});

final bookmarksProvider =
    FutureProvider.family<List<Bookmark>, String?>((ref, kind) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).bookmarks(kind: kind);
});

final bookmarkAtProvider = FutureProvider.family<bool, (String, int)>((ref, key) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).isBookmarked(key.$1, key.$2);
});

final todoProvider = FutureProvider<List<Todo>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(storeProvider).todos();
});

final storyReadProvider = FutureProvider.family<bool, int>((ref, id) async {
  ref.watch(revisionProvider);
  final raw = await ref.watch(storeProvider).kvGet('story_read_$id');
  return raw != null;
});

/// Global ayah numbers counted today.
final readSetProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(revisionProvider);
  final date = dayKey(ref.watch(todayProvider));
  final raw = await ref.watch(storeProvider).kvGet('read_set_$date') ?? '';
  return raw
      .split(',')
      .where((s) => s.isNotEmpty)
      .map(int.parse)
      .toSet();
});

/// Hadith ids counted as learned today, so each hadith counts once per day.
final hadithReadSetProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(revisionProvider);
  final date = dayKey(ref.watch(todayProvider));
  final raw =
      await ref.watch(storeProvider).kvGet('hadith_read_set_$date') ?? '';
  return raw
      .split(',')
      .where((s) => s.isNotEmpty)
      .map(int.parse)
      .toSet();
});

// ---------------------------------------------------------------- actions

class AlimActions {
  AlimActions(this._ref);

  final Ref _ref;

  AlimStore get _store => _ref.read(storeProvider);
  Profile get _profile => _ref.read(profileProvider);

  void _bump() => _ref.read(revisionProvider.notifier).state++;

  DateTime get _now => _ref.read(todayProvider);
  String get _today => dayKey(_now);

  Future<DayLog> _logNow() => _store.day(_today);

  List<DailyTask> _tasksNow() => buildDailyTasks(
        date: _now,
        versesGoal: _profile.versesGoal,
      );

  /// Awards XP for every task that crossed from open to done because of the
  /// activity, then the all-tasks bonus, once.
  Future<void> _settle(DayLog before) async {
    final after = await _logNow();
    final tasks = _tasksNow();
    for (final t in tasks) {
      if (t.kind == DailyTaskKind.manual) continue;
      final was = isTaskDone(t, before, before.tasks);
      final now = isTaskDone(t, after, after.tasks);
      if (!was && now) {
        await _store.addXp(_today, t.xp);
      }
    }
    final settled = await _logNow();
    if (deservesAllDoneBonus(tasks, settled, settled.tasks)) {
      final key = 'bonus_$_today';
      if (await _store.kvGet(key) == null) {
        await _store.kvSet(key, '1');
        await _store.addXp(_today, allTasksBonus);
        final perfect = int.tryParse(await _store.kvGet('perfect_days') ?? '') ?? 0;
        await _store.kvSet('perfect_days', '${perfect + 1}');
      }
    }
    _bump();
  }

  Future<void> markManualTask(String id, bool done) async {
    final before = await _logNow();
    await _store.setTaskDone(_today, id, done);
    if (done) {
      final tasks = _tasksNow();
      final task = tasks.firstWhere((t) => t.id == id,
          orElse: () => tasks.last);
      final was = isTaskDone(task, before, before.tasks);
      if (!was) await _store.addXp(_today, task.xp);
    }
    await _settle(before);
  }

  Future<void> addDhikr(int n) async {
    final before = await _logNow();
    await _store.addDhikr(_today, n);
    await _settle(before);
  }

  Future<void> setGratitude(String text) async {
    final before = await _logNow();
    await _store.setGratitude(_today, text);
    await _settle(before);
  }

  /// Counts a hadith as learned today. The first time a given hadith is
  /// opened today it adds to the day; opening the same hadith again, or any
  /// other hadith opened again, does not double count.
  Future<bool> learnedHadith(int hadithId) async {
    final key = 'hadith_read_set_$_today';
    final raw = await _store.kvGet(key) ?? '';
    final read = raw.split(',').where((s) => s.isNotEmpty).toSet();
    if (read.contains('$hadithId')) {
      _bump();
      return false;
    }
    read.add('$hadithId');
    await _store.kvSet(key, read.join(','));
    final before = await _logNow();
    await _store.addHadiths(_today, 1);
    await _settle(before);
    return true;
  }

  Future<void> readStory(int id) async {
    final already = await _store.kvGet('story_read_$id');
    final before = await _logNow();
    await _store.addStories(_today, 1);
    await _store.kvSet('story_read_$id', _today);
    if (already == null) {
      await _store.addXp(_today, 20);
    }
    await _settle(before);
  }

  /// Marks an ayah as read today. Returns true when this is the first time
  /// today, so the caller can animate.
  Future<bool> markAyahRead(int ayahNumber) async {
    final key = 'read_set_$_today';
    final raw = await _store.kvGet(key) ?? '';
    final read = raw.split(',').where((s) => s.isNotEmpty).toSet();
    if (read.contains('$ayahNumber')) {
      _bump();
      return false;
    }
    read.add('$ayahNumber');
    await _store.kvSet(key, read.join(','));
    final before = await _logNow();
    await _store.addVerses(_today, 1);
    await _settle(before);
    return true;
  }

  Future<void> setLastRead(int ayahNumber) async {
    await _store.setLastRead(ayahNumber);
    _bump();
  }

  /// Reads a fresh fix and remembers it. Throws [LocationProblemException]
  /// when the service is off, the permission is refused, or no fix arrives.
  Future<AlimLocation> locate() async {
    final place = await LocationService.current();
    await _store.kvSet('location', '${place.latitude},${place.longitude}');
    _bump();
    return place;
  }

  Future<void> forgetLocation() async {
    await _store.kvSet('location', '');
    _bump();
  }

  Future<void> toggleBookmark(String kind, int refId, String label) async {
    await _store.toggleBookmark(kind, refId, label);
    _bump();
  }

  Future<void> addTodo(String title, {String? due}) async {
    await _store.addTodo(title, due: due);
    _bump();
  }

  Future<void> toggleTodo(int id) async {
    await _store.toggleTodo(id);
    _bump();
  }

  Future<void> deleteTodo(int id) async {
    await _store.deleteTodo(id);
    _bump();
  }

  Future<void> saveProfile(Profile next) async {
    await _ref.read(profileProvider.notifier).save(next);
    _bump();
  }
}

final actionsProvider = Provider<AlimActions>((ref) => AlimActions(ref));

// ---------------------------------------------------------------- badges

class AlimBadge {
  const AlimBadge(this.id, this.title, this.description, this._earned);

  final String id;
  final String title;
  final String description;
  final bool Function(JourneyStats) _earned;

  bool earned(JourneyStats stats) => _earned(stats);
}

final badges = <AlimBadge>[
  AlimBadge('first-day', 'First light', 'A first day with Alim', (s) => s.activeDays >= 1),
  AlimBadge('streak-7', 'Seven in a row', 'A full week of kept days', (s) => s.bestStreak >= 7),
  AlimBadge('streak-30', 'Steadfast', 'Thirty days in a row', (s) => s.bestStreak >= 30),
  AlimBadge('ayat-100', 'Hundred ayat', 'One hundred ayat read', (s) => s.verses >= 100),
  AlimBadge('ayat-1000', 'A thousand ayat', 'One thousand ayat read', (s) => s.verses >= 1000),
  AlimBadge('mushaf', 'The whole mushaf', 'All 6,236 ayat read at least once', (s) => s.verses >= 6236),
  AlimBadge('hadith-40', 'Forty hadith', 'Forty authentic hadith learned', (s) => s.hadiths >= 40),
  AlimBadge('hadith-500', 'Companion of hadith', 'Five hundred hadith learned', (s) => s.hadiths >= 500),
  AlimBadge('dhikr-1000', 'Tongue moist', 'A thousand remembrances', (s) => s.dhikr >= 1000),
  AlimBadge('story-all', 'The story keeper', 'Every story read', (s) => s.stories >= 46),
  AlimBadge('perfect', 'A perfect day', 'Every task of a day completed', (s) => s.perfectDays >= 1),
  AlimBadge('perfect-7', 'Perfect week', 'Seven perfect days', (s) => s.perfectDays >= 7),
  AlimBadge('bookmarks', 'Thread keeper', 'Ten bookmarks saved', (s) => s.bookmarks >= 10),
  AlimBadge('rank-devoted', 'Devoted', 'Nine hundred XP earned', (s) => s.xp >= 900),
  AlimBadge('rank-alim', 'Alim', 'Twelve thousand XP earned', (s) => s.xp >= 12000),
];
