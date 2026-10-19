import '../models.dart';

// The rules of the day: which tasks exist, how they are judged done, how XP
// becomes a rank, how the dhikr counter moves through its phrases, and which
// verses, hadith and stories the day gets.
//
// Everything here is pure so it can be tested without a database.

class DailyTask {
  const DailyTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.kind,
    this.goal,
  });

  final String id;
  final String title;
  final String subtitle;
  final int xp;
  final DailyTaskKind kind;

  /// For the Qur'an task: the number of ayat that makes it done.
  final int? goal;
}

enum DailyTaskKind { quran, hadith, dhikr, gratitude, story, manual }

/// The fifth task changes with the day of the week, so a week has seven faces.
const rotationTasks = <int, DailyTask>{
  1: DailyTask(
    id: 'rot-mon',
    title: 'Review Surah Al-Ikhlas',
    subtitle: 'One short surah, from memory. It is worth a third of the Qur\'an.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
  2: DailyTask(
    id: 'rot-tue',
    title: 'Read one story',
    subtitle: 'A prophet, a companion or a lesson from the earlier ones.',
    xp: 20,
    kind: DailyTaskKind.story,
  ),
  3: DailyTask(
    id: 'rot-wed',
    title: 'Ten salawat',
    subtitle: 'Peace and blessings on the Prophet ﷺ, ten times.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
  4: DailyTask(
    id: 'rot-thu',
    title: 'Dua for your parents',
    subtitle: 'The night before Jumu\'ah. Ask Allah for the two who raised you.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
  5: DailyTask(
    id: 'rot-fri',
    title: 'Read Surah Al-Kahf',
    subtitle: 'The Friday surah, light between the two Fridays.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
  6: DailyTask(
    id: 'rot-sat',
    title: 'Keep one ayah in your heart',
    subtitle: 'Choose a short ayah and repeat it until it is yours.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
  7: DailyTask(
    id: 'rot-sun',
    title: 'Give something away',
    subtitle: 'Sadaqah does not have to be money. Start the week open-handed.',
    xp: 20,
    kind: DailyTaskKind.manual,
  ),
};

List<DailyTask> buildDailyTasks({
  required DateTime date,
  required int versesGoal,
}) {
  return [
    DailyTask(
      id: 'quran',
      title: 'Read $versesGoal ${versesGoal == 1 ? 'ayah' : 'ayat'}',
      subtitle: 'Tap ayat in the reader as you go; Alim keeps the count.',
      xp: 20,
      kind: DailyTaskKind.quran,
      goal: versesGoal,
    ),
    const DailyTask(
      id: 'hadith',
      title: 'Learn today\'s hadith',
      subtitle: 'One authentic hadith, a minute of your time.',
      xp: 20,
      kind: DailyTaskKind.hadith,
    ),
    const DailyTask(
      id: 'dhikr',
      title: 'Dhikr 100',
      subtitle: 'SubhanAllah 33 · Alhamdulillah 33 · Allahu Akbar 34.',
      xp: 20,
      kind: DailyTaskKind.dhikr,
    ),
    const DailyTask(
      id: 'gratitude',
      title: 'Write one line of gratitude',
      subtitle: 'One thing today was a gift.',
      xp: 20,
      kind: DailyTaskKind.gratitude,
    ),
    rotationTasks[date.weekday]!,
  ];
}

/// A task's done-ness is derived from the day's record, except for the manual
/// rotation tasks, which the person ticks themselves.
bool isTaskDone(DailyTask task, DayLog log, Set<String> manual) {
  switch (task.kind) {
    case DailyTaskKind.quran:
      return log.verses >= (task.goal ?? 1);
    case DailyTaskKind.hadith:
      return log.hadiths > 0;
    case DailyTaskKind.dhikr:
      return log.dhikr >= 100;
    case DailyTaskKind.gratitude:
      return log.gratitude.trim().isNotEmpty;
    case DailyTaskKind.story:
      return log.stories > 0;
    case DailyTaskKind.manual:
      return manual.contains(task.id);
  }
}

const allTasksBonus = 25;

/// The bonus is granted once per day, the first time every task of the day is
/// done. The caller records the day in `all_done_days`.
bool deservesAllDoneBonus(List<DailyTask> tasks, DayLog log, Set<String> manual) =>
    tasks.every((t) => isTaskDone(t, log, manual));

// ------------------------------------------------------------------- ranks

class AlimRank {
  const AlimRank(this.floor, this.title, this.arabic);

  final int floor;
  final String title;
  final String arabic;
}

const ranks = <AlimRank>[
  AlimRank(0, 'Seeker', 'طالب'),
  AlimRank(300, 'Learner', 'متعلّم'),
  AlimRank(900, 'Devoted', 'عابد'),
  AlimRank(1800, 'Steadfast', 'ثابت'),
  AlimRank(3600, 'Guardian', 'حافظ'),
  AlimRank(7200, 'Sage', 'حكيم'),
  AlimRank(12000, 'Alim', 'عالم'),
];

AlimRank rankFor(int xp) {
  var rank = ranks.first;
  for (final r in ranks) {
    if (xp >= r.floor) rank = r;
  }
  return rank;
}

/// 0..1 toward the next rank; 1 when at the last rank.
double rankProgress(int xp) {
  final current = rankFor(xp);
  final i = ranks.indexOf(current);
  if (i == ranks.length - 1) return 1;
  final next = ranks[i + 1];
  return ((xp - current.floor) / (next.floor - current.floor)).clamp(0, 1);
}

// ------------------------------------------------------------------- dhikr

class DhikrPhase {
  const DhikrPhase(this.arabic, this.transliteration, this.meaning, this.count);

  final String arabic;
  final String transliteration;
  final String meaning;
  final int count;
}

const dhikrPhases = <DhikrPhase>[
  DhikrPhase('سُبْحَانَ اللَّهِ', 'SubhanAllah', 'Glory be to Allah', 33),
  DhikrPhase('الْحَمْدُ لِلَّهِ', 'Alhamdulillah', 'All praise is for Allah', 33),
  DhikrPhase('اللَّهُ أَكْبَرُ', 'Allahu Akbar', 'Allah is the Greatest', 34),
];

const dhikrTotal = 100;

/// Which phrase the counter is on after [done] taps today.
int dhikrPhaseIndex(int done) {
  if (done < 33) return 0;
  if (done < 66) return 1;
  return 2;
}

/// Taps done within the current phrase.
int dhikrInPhase(int done) => done - phaseFloor(dhikrPhaseIndex(done));

int phaseFloor(int index) {
  var sum = 0;
  for (var i = 0; i < index; i++) {
    sum += dhikrPhases[i].count;
  }
  return sum;
}

// ------------------------------------------------------ verses of the day

/// Thirty passages that between them carry the heart of the message. The day
/// picks one by turning of the year, so it is the same for everyone and it
/// never repeats within a month.
const verseOfDayRefs = <List<int>>[
  [2, 255], [2, 286], [3, 8], [3, 139], [3, 159],
  [13, 28], [14, 7], [17, 80], [20, 114], [24, 35],
  [25, 74], [29, 69], [33, 41], [39, 53], [40, 60],
  [49, 13], [55, 13], [57, 4], [59, 22], [64, 11],
  [65, 3], [66, 8], [67, 1], [73, 8], [87, 14],
  [93, 5], [94, 5], [103, 3], [108, 1], [112, 1],
];

int dayNumber(DateTime date) => DateTime(date.year, date.month, date.day)
    .difference(DateTime(2026, 1, 1))
    .inDays;

List<int> verseRefOfDay(DateTime date) =>
    verseOfDayRefs[dayNumber(date) % verseOfDayRefs.length];

// -------------------------------------------------------------- the bands

/// A day is kept when at least two tasks were finished. That is the working
/// definition behind the streak flame.
bool dayIsKept(List<DailyTask> tasks, DayLog log, Set<String> manual) {
  var done = 0;
  for (final t in tasks) {
    if (isTaskDone(t, log, manual)) done++;
  }
  return done >= 2;
}

/// The chapter of the Qur'an sixty ayat ahead of where the person stopped, so
/// "continue" always has somewhere to go.
int chapterAfter(int ayahNumber, List<Surah> surahs) {
  for (final s in surahs) {
    if (ayahNumber < s.firstAyah) return s.number;
  }
  return surahs.last.number;
}

String greetingFor(DateTime time) {
  if (time.hour < 5) return 'Peace in the night';
  if (time.hour < 12) return 'Peace be upon you';
  if (time.hour < 17) return 'Peace in the afternoon';
  if (time.hour < 20) return 'Peace in the evening';
  return 'Peace tonight';
}
