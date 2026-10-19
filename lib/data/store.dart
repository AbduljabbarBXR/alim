import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

/// The one door to everything stored: the shipped content (Qur'an, hadith,
/// stories) and the person's own record of reading, bookmarks, plan and days.
///
/// The content database ships gzipped. On first launch it is expanded into the
/// app's databases directory, which is writable, so there is exactly one file
/// to talk to afterwards.
class AlimStore {
  AlimStore._(this._db);

  final Database _db;

  static const _contentAsset = 'assets/db/alim.db.gz';

  static Future<AlimStore> open({String? overridePath}) async {
    final dir = overridePath ?? await getDatabasesPath();
    final file = File(p.join(dir, 'alim.db'));
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final compressed = await rootBundle.load(_contentAsset);
      final bytes = gzip.decode(
        compressed.buffer.asUint8List(
          compressed.offsetInBytes,
          compressed.lengthInBytes,
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
    }
    final db = await openDatabase(file.path);
    await _migrate(db);
    return AlimStore._(db);
  }

  /// User tables are created here as well as in the build so that an install
  /// from an older build gains whatever was added since.
  static Future<void> _migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmark (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        ref INTEGER NOT NULL,
        label TEXT NOT NULL,
        created TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmark ON bookmark(kind, ref)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily (
        date TEXT PRIMARY KEY,
        verses INTEGER NOT NULL DEFAULT 0,
        hadiths INTEGER NOT NULL DEFAULT 0,
        stories INTEGER NOT NULL DEFAULT 0,
        dhikr INTEGER NOT NULL DEFAULT 0,
        xp INTEGER NOT NULL DEFAULT 0,
        tasks TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS todo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        due TEXT,
        done INTEGER NOT NULL DEFAULT 0,
        created TEXT NOT NULL,
        completed_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gratitude (
        date TEXT PRIMARY KEY,
        text TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------- content

  Future<List<Surah>> surahs() async {
    final rows = await _db.query('surah', orderBy: 'number');
    return rows.map(Surah.fromMap).toList();
  }

  Future<Surah> surah(int number) async {
    final rows = await _db.query('surah',
        where: 'number = ?', whereArgs: [number], limit: 1);
    return Surah.fromMap(rows.single);
  }

  Future<List<Ayah>> ayatOf(int surah) async {
    final rows = await _db.query('ayah',
        where: 'surah = ?', whereArgs: [surah], orderBy: 'ayah');
    return rows.map(Ayah.fromMap).toList();
  }

  Future<Ayah> ayah(int number) async {
    final rows = await _db
        .query('ayah', where: 'number = ?', whereArgs: [number], limit: 1);
    return Ayah.fromMap(rows.single);
  }

  Future<Ayah> ayahAt(int surah, int ayah) async {
    final rows = await _db.query('ayah',
        where: 'surah = ? AND ayah = ?', whereArgs: [surah, ayah], limit: 1);
    return Ayah.fromMap(rows.single);
  }

  Future<Surah> surahOfAyah(int ayahNumber) async {
    final rows = await _db.query('surah',
        where: 'first_ayah <= ? AND first_ayah + ayat > ?',
        whereArgs: [ayahNumber, ayahNumber],
        limit: 1);
    return Surah.fromMap(rows.single);
  }

  Future<List<Ayah>> searchAyat(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final en = q.toLowerCase();
    final ar = normalizeArabic(q);
    final rows = await _db.query(
      'ayah',
      where: 'en_search LIKE ? OR ar_search LIKE ?',
      whereArgs: ['%$en%', '%$ar%'],
      orderBy: 'number',
      limit: limit,
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<List<HadithCollection>> hadithCollections() async {
    final rows = await _db.query('hadith_collection');
    final items = rows.map(HadithCollection.fromMap).toList();
    const order = ['bukhari', 'muslim', 'nawawi', 'qudsi'];
    items.sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
    return items;
  }

  Future<List<HadithBook>> hadithBooks(String collection) async {
    final rows = await _db.rawQuery('''
      SELECT b.number, b.collection, b.title, COUNT(h.id) AS count
      FROM hadith_book b
      LEFT JOIN hadith h ON h.collection = b.collection AND h.book = b.number
      WHERE b.collection = ?
      GROUP BY b.id
      HAVING count > 0
      ORDER BY b.number
    ''', [collection]);
    return rows
        .map((m) => HadithBook(
              number: m['number'] as int,
              collection: m['collection'] as String,
              title: m['title'] as String,
              count: (m['count'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<HadithCollection> hadithCollection(String id) async {
    final rows = await _db.query('hadith_collection',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return HadithCollection.fromMap(rows.single);
  }

  Future<List<Hadith>> hadithsOfBook(
    String collection,
    int book, {
    int limit = 2000,
    int offset = 0,
  }) async {
    final rows = await _db.query('hadith',
        where: 'collection = ? AND book = ?',
        whereArgs: [collection, book],
        orderBy: 'number_in_book',
        limit: limit,
        offset: offset);
    return rows.map(Hadith.fromMap).toList();
  }

  Future<Hadith> hadithById(int id) async {
    final rows =
        await _db.query('hadith', where: 'id = ?', whereArgs: [id], limit: 1);
    return Hadith.fromMap(rows.single);
  }

  Future<int> shortHadithCount() async {
    final rows =
        await _db.rawQuery('SELECT COUNT(*) AS n FROM hadith WHERE short = 1');
    return rows.single['n'] as int;
  }

  /// The nth short hadith, in a stable order, for "hadith of the day".
  Future<Hadith> shortHadithAt(int index) async {
    final rows = await _db.query('hadith',
        where: 'short = 1', orderBy: 'id', limit: 1, offset: index);
    return Hadith.fromMap(rows.single);
  }

  Future<List<Story>> stories() async {
    final rows = await _db.query('story', orderBy: 'id');
    return rows.map(Story.fromMap).toList();
  }

  Future<Story> story(int id) async {
    final rows =
        await _db.query('story', where: 'id = ?', whereArgs: [id], limit: 1);
    return Story.fromMap(rows.single);
  }

  // ------------------------------------------------------------------- user

  Future<String?> kvGet(String key) async {
    final rows = await _db
        .query('user_kv', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.single['value'] as String;
  }

  Future<void> kvSet(String key, String value) async {
    await _db.insert('user_kv', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> lastRead() async {
    final raw = await kvGet('last_read');
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> setLastRead(int ayahNumber) =>
      kvSet('last_read', '$ayahNumber');

  Future<bool> isBookmarked(String kind, int ref) async {
    final rows = await _db.query('bookmark',
        where: 'kind = ? AND ref = ?', whereArgs: [kind, ref], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> toggleBookmark(String kind, int ref, String label) async {
    final rows = await _db.query('bookmark',
        where: 'kind = ? AND ref = ?', whereArgs: [kind, ref], limit: 1);
    if (rows.isNotEmpty) {
      await _db
          .delete('bookmark', where: 'kind = ? AND ref = ?', whereArgs: [kind, ref]);
      return;
    }
    await _db.insert('bookmark', {
      'kind': kind,
      'ref': ref,
      'label': label,
      'created': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Bookmark>> bookmarks({String? kind}) async {
    final rows = await _db.query('bookmark',
        where: kind == null ? null : 'kind = ?',
        whereArgs: kind == null ? null : [kind],
        orderBy: 'created DESC');
    return rows.map(Bookmark.fromMap).toList();
  }

  static String todayKey(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<DayLog> day(String date) async {
    final rows =
        await _db.query('daily', where: 'date = ?', whereArgs: [date], limit: 1);
    final gRows = await _db.query('gratitude',
        where: 'date = ?', whereArgs: [date], limit: 1);
    final gratitude =
        gRows.isEmpty ? '' : gRows.single['text'] as String;
    if (rows.isEmpty) {
      return DayLog(
        date: date,
        verses: 0,
        hadiths: 0,
        stories: 0,
        dhikr: 0,
        xp: 0,
        tasks: const {},
        gratitude: gratitude,
      );
    }
    return DayLog.fromMap(rows.single, gratitude: gratitude);
  }

  Future<void> _bump(String date, String column, int amount) async {
    await _db.rawInsert('''
      INSERT INTO daily (date, $column) VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET $column = $column + excluded.$column
    ''', [date, amount]);
  }

  Future<void> addVerses(String date, int n) => _bump(date, 'verses', n);
  Future<void> addHadiths(String date, int n) => _bump(date, 'hadiths', n);
  Future<void> addStories(String date, int n) => _bump(date, 'stories', n);
  Future<void> addDhikr(String date, int n) => _bump(date, 'dhikr', n);
  Future<void> addXp(String date, int n) => _bump(date, 'xp', n);

  Future<Set<String>> dayTasks(String date) async => (await day(date)).tasks;

  Future<void> setTaskDone(String date, String id, bool done) async {
    final current = {...await dayTasks(date)};
    if (done) {
      current.add(id);
    } else {
      current.remove(id);
    }
    final json = '{${current.map((t) => '"$t"').join(',')}}';
    await _db.rawInsert('''
      INSERT INTO daily (date, tasks) VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET tasks = excluded.tasks
    ''', [date, json]);
  }

  Future<void> setGratitude(String date, String text) async {
    if (text.trim().isEmpty) {
      await _db.delete('gratitude', where: 'date = ?', whereArgs: [date]);
      return;
    }
    await _db.insert('gratitude', {'date': date, 'text': text.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Todo>> todos({bool includeDone = true}) async {
    final rows = await _db.query('todo',
        where: includeDone ? null : 'done = 0',
        orderBy: 'done ASC, due IS NULL, due ASC, id ASC');
    return rows.map(Todo.fromMap).toList();
  }

  Future<int> addTodo(String title, {String? due}) async {
    return _db.insert('todo', {
      'title': title.trim(),
      'due': due,
      'done': 0,
      'created': DateTime.now().toIso8601String(),
    });
  }

  Future<void> toggleTodo(int id) async {
    final rows =
        await _db.query('todo', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final done = (rows.single['done'] as int? ?? 0) == 1;
    await _db.update(
      'todo',
      {
        'done': done ? 0 : 1,
        'completed_at': done ? null : DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTodo(int id) async {
    await _db.delete('todo', where: 'id = ?', whereArgs: [id]);
  }

  Future<JourneyStats> stats({required DateTime now}) async {
    Future<int> sum(String column) async {
      final rows = await _db
          .rawQuery('SELECT COALESCE(SUM($column), 0) AS n FROM daily');
      return rows.single['n'] as int;
    }

    final rows = await _db.rawQuery(
        'SELECT date FROM daily WHERE verses + hadiths + stories + dhikr + xp > 0 ORDER BY date');
    final dates = rows.map((r) => r['date'] as String).toList();
    final active = dates.toSet();

    var streak = 0;
    var cursor = now;
    var guard = 0;
    // A day counts when it has any activity; the streak survives a day that is
    // still in progress by starting the walk from today.
    while (guard < 4000) {
      guard++;
      final key = todayKey(cursor);
      if (active.contains(key)) {
        streak++;
      } else if (streak == 0 && guard == 1) {
        // Today may not have happened yet; look back one day.
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in dates) {
      final parsed = DateTime.tryParse(d);
      if (parsed == null) continue;
      if (prev != null && parsed.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = parsed;
    }

    final bookmarkRows = await _db.rawQuery('SELECT COUNT(*) AS n FROM bookmark');
    final storyRows =
        await _db.rawQuery('SELECT COALESCE(SUM(stories), 0) AS n FROM daily');
    final perfectRaw = await kvGet('perfect_days');

    return JourneyStats(
      verses: await sum('verses'),
      hadiths: await sum('hadiths'),
      stories: storyRows.single['n'] as int,
      dhikr: await sum('dhikr'),
      activeDays: active.length,
      streak: streak,
      bestStreak: best,
      xp: await sum('xp'),
      bookmarks: bookmarkRows.single['n'] as int,
      perfectDays: int.tryParse(perfectRaw ?? '') ?? 0,
    );
  }

  /// Verses read on each of the last [days] days, oldest first.
  Future<List<int>> versesLastDays(int days, {required DateTime now}) async {
    final out = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final log = await day(todayKey(d));
      out.add(log.verses);
    }
    return out;
  }

  Future<void> eraseUserData() async {
    for (final table in const [
      'daily',
      'bookmark',
      'todo',
      'gratitude',
      'user_kv',
    ]) {
      await _db.delete(table);
    }
  }

  Future<void> close() => _db.close();
}

/// Mirrors the normalization used when the database was built, so a search for
/// "الفاتحه" finds "الْفَاتِحَةِ".
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    if (RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]')
        .hasMatch(ch)) {
      continue;
    }
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        buffer.write('ا');
      case 'ى':
      case 'ئ':
        buffer.write('ي');
      case 'ؤ':
        buffer.write('و');
      case 'ة':
        buffer.write('ه');
      default:
        buffer.write(ch);
    }
  }
  return buffer.toString();
}
