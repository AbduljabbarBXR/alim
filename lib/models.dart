/// The shapes the database speaks in.
library;

class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.meaning,
    required this.nameAr,
    required this.revelation,
    required this.ayat,
    required this.firstAyah,
  });

  final int number;
  final String name;
  final String meaning;
  final String nameAr;
  final String revelation;
  final int ayat;

  /// The global ayah number of this surah's first verse, so progress can be
  /// measured as a single number across the whole mushaf.
  final int firstAyah;

  int get lastAyah => firstAyah + ayat - 1;

  factory Surah.fromMap(Map<String, Object?> m) => Surah(
    number: m['number'] as int,
    name: m['name'] as String,
    meaning: m['meaning'] as String,
    nameAr: m['name_ar'] as String,
    revelation: m['revelation'] as String,
    ayat: m['ayat'] as int,
    firstAyah: m['first_ayah'] as int,
  );
}

class Ayah {
  const Ayah({
    required this.number,
    required this.surah,
    required this.ayah,
    required this.juz,
    required this.page,
    required this.sajda,
    required this.textAr,
    required this.textEn,
  });

  final int number;
  final int surah;
  final int ayah;
  final int juz;
  final int page;
  final bool sajda;
  final String textAr;
  final String textEn;

  factory Ayah.fromMap(Map<String, Object?> m) => Ayah(
    number: m['number'] as int,
    surah: m['surah'] as int,
    ayah: m['ayah'] as int,
    juz: m['juz'] as int,
    page: m['page'] as int,
    sajda: (m['sajda'] as int? ?? 0) == 1,
    textAr: m['text_ar'] as String,
    textEn: m['text_en'] as String,
  );
}

class Translation {
  const Translation({
    required this.id,
    required this.slug,
    required this.title,
    required this.translator,
    required this.year,
    required this.source,
  });

  final int id;
  final String slug;
  final String title;
  final String translator;
  final String year;
  final String source;

  factory Translation.fromMap(Map<String, Object?> m) => Translation(
    id: m['id'] as int,
    slug: m['slug'] as String,
    title: m['title'] as String,
    translator: m['translator'] as String,
    year: m['year'] as String,
    source: m['source'] as String,
  );
}

class HadithCollection {
  const HadithCollection({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.blurb,
    required this.count,
  });

  final String id;
  final String name;
  final String arabicName;
  final String blurb;
  final int count;

  factory HadithCollection.fromMap(Map<String, Object?> m) => HadithCollection(
    id: m['id'] as String,
    name: m['name'] as String,
    arabicName: m['arabic_name'] as String,
    blurb: m['blurb'] as String,
    count: m['count'] as int,
  );
}

class HadithBook {
  const HadithBook({
    required this.number,
    required this.collection,
    required this.title,
    required this.count,
  });

  final int number;
  final String collection;
  final String title;
  final int count;
}

class Hadith {
  const Hadith({
    required this.id,
    required this.collection,
    required this.book,
    required this.numberInBook,
    required this.textEn,
    required this.textAr,
  });

  final int id;
  final String collection;
  final int book;
  final int numberInBook;
  final String textEn;
  final String textAr;

  factory Hadith.fromMap(Map<String, Object?> m) => Hadith(
    id: m['id'] as int,
    collection: m['collection'] as String,
    book: m['book'] as int,
    numberInBook: m['number_in_book'] as int,
    textEn: m['text_en'] as String,
    textAr: m['text_ar'] as String,
  );
}

class Story {
  const Story({
    required this.id,
    required this.category,
    required this.title,
    required this.minutes,
    required this.body,
    required this.lesson,
    required this.ayahRef,
    required this.ayahNumber,
    required this.hadithId,
    required this.hadithRef,
  });

  final int id;
  final String category;
  final String title;
  final int minutes;
  final String body;
  final String lesson;
  final String? ayahRef;

  /// The global ayah number the story points at, when it points at one.
  final int? ayahNumber;

  /// The hadith row that carries the story in the Sunnah, when one matched.
  final int? hadithId;

  /// A readable reference for that hadith, e.g. "Sahih al-Bukhari 3364".
  final String? hadithRef;

  List<String> get paragraphs =>
      body.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

  factory Story.fromMap(Map<String, Object?> m) => Story(
    id: m['id'] as int,
    category: m['category'] as String,
    title: m['title'] as String,
    minutes: m['minutes'] as int,
    body: m['body'] as String,
    lesson: m['lesson'] as String,
    ayahRef: m['ayah_ref'] as String?,
    ayahNumber: m['ayah_number'] as int?,
    hadithId: m['hadith_id'] as int?,
    hadithRef: m['hadith_ref'] as String?,
  );
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.kind,
    required this.ref,
    required this.label,
    required this.created,
  });

  final int id;
  final String kind;
  final int ref;
  final String label;
  final String created;

  factory Bookmark.fromMap(Map<String, Object?> m) => Bookmark(
    id: m['id'] as int,
    kind: m['kind'] as String,
    ref: m['ref'] as int,
    label: m['label'] as String,
    created: m['created'] as String,
  );
}

class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.due,
    required this.done,
  });

  final int id;
  final String title;
  final String? due;
  final bool done;

  factory Todo.fromMap(Map<String, Object?> m) => Todo(
    id: m['id'] as int,
    title: m['title'] as String,
    due: m['due'] as String?,
    done: (m['done'] as int? ?? 0) == 1,
  );
}

class DayLog {
  const DayLog({
    required this.date,
    required this.verses,
    required this.hadiths,
    required this.stories,
    required this.dhikr,
    required this.xp,
    required this.tasks,
    required this.gratitude,
  });

  final String date;
  final int verses;
  final int hadiths;
  final int stories;
  final int dhikr;
  final int xp;
  final Set<String> tasks;
  final String gratitude;

  factory DayLog.fromMap(Map<String, Object?> m, {String gratitude = ''}) =>
      DayLog(
        date: m['date'] as String,
        verses: m['verses'] as int? ?? 0,
        hadiths: m['hadiths'] as int? ?? 0,
        stories: m['stories'] as int? ?? 0,
        dhikr: m['dhikr'] as int? ?? 0,
        xp: m['xp'] as int? ?? 0,
        tasks:
            ((m['tasks'] as String?) ?? '{}')
                .replaceAll('{', '')
                .replaceAll('}', '')
                .replaceAll('"', '')
                .split(',')
                .where((s) => s.trim().isNotEmpty)
                .toSet(),
        gratitude: gratitude,
      );
}

/// Everything Me shows about the journey.
class JourneyStats {
  const JourneyStats({
    required this.verses,
    required this.hadiths,
    required this.stories,
    required this.dhikr,
    required this.activeDays,
    required this.streak,
    required this.bestStreak,
    required this.xp,
    required this.bookmarks,
    required this.perfectDays,
  });

  final int verses;
  final int hadiths;
  final int stories;
  final int dhikr;
  final int activeDays;
  final int streak;
  final int bestStreak;
  final int xp;
  final int bookmarks;
  final int perfectDays;
}

class Profile {
  const Profile({
    this.name = '',
    this.versesGoal = 5,
    this.translationOn = true,
    this.translation = 'sahih',
    this.arabicScale = 1.0,
    this.darkMode = false,
    this.themeMode = 'system',
    this.reciter = 'alafasy',
    this.downloadBeforePlay = true,
    this.adhanOn = false,
    this.adhanSound = 'short',
    this.adhanPrayers = 'fajr,dhuhr,asr,maghrib,isha',
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.reminderOn = false,
    this.prayerMethod = 'muslimWorldLeague',
    this.asrHanafi = false,
  });

  final String name;
  final int versesGoal;
  final bool translationOn;
  final String translation;
  final double arabicScale;
  final bool darkMode;
  final String themeMode;
  final String reciter;
  final bool downloadBeforePlay;
  final bool adhanOn;
  final String adhanSound;
  final String adhanPrayers;
  final int reminderHour;
  final int reminderMinute;
  final bool reminderOn;
  final String prayerMethod;
  final bool asrHanafi;

  Profile copyWith({
    String? name,
    int? versesGoal,
    bool? translationOn,
    String? translation,
    double? arabicScale,
    bool? darkMode,
    String? themeMode,
    String? reciter,
    bool? downloadBeforePlay,
    bool? adhanOn,
    String? adhanSound,
    String? adhanPrayers,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderOn,
    String? prayerMethod,
    bool? asrHanafi,
  }) => Profile(
    name: name ?? this.name,
    versesGoal: versesGoal ?? this.versesGoal,
    translationOn: translationOn ?? this.translationOn,
    translation: translation ?? this.translation,
    arabicScale: arabicScale ?? this.arabicScale,
    darkMode: darkMode ?? this.darkMode,
    themeMode: themeMode ?? this.themeMode,
    reciter: reciter ?? this.reciter,
    downloadBeforePlay: downloadBeforePlay ?? this.downloadBeforePlay,
    adhanOn: adhanOn ?? this.adhanOn,
    adhanSound: adhanSound ?? this.adhanSound,
    adhanPrayers: adhanPrayers ?? this.adhanPrayers,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    reminderOn: reminderOn ?? this.reminderOn,
    prayerMethod: prayerMethod ?? this.prayerMethod,
    asrHanafi: asrHanafi ?? this.asrHanafi,
  );
}
