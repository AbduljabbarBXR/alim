import 'package:alim/models.dart';
import 'package:alim/services/daily.dart';
import 'package:alim/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

DayLog blank(DateTime date) => DayLog(
  date: '2026-01-05',
  verses: 0,
  hadiths: 0,
  stories: 0,
  dhikr: 0,
  xp: 0,
  tasks: const {},
  gratitude: '',
);

void main() {
  group('daily tasks', () {
    test('a day has five tasks and the Qur\'an goal is the profile goal', () {
      final tasks = buildDailyTasks(date: DateTime(2026, 1, 5), versesGoal: 5);
      expect(tasks, hasLength(5));
      expect(tasks[0].kind, DailyTaskKind.quran);
      expect(tasks[0].title, 'Read 5 ayat');
      expect(tasks[0].goal, 5);
      expect(tasks.map((t) => t.id).toSet(), {
        'quran',
        'hadith',
        'dhikr',
        'gratitude',
        'rot-mon',
      });
    });

    test('the rotating task follows the weekday', () {
      final monday = buildDailyTasks(date: DateTime(2026, 1, 5), versesGoal: 5);
      final friday = buildDailyTasks(date: DateTime(2026, 1, 9), versesGoal: 5);
      final sunday = buildDailyTasks(
        date: DateTime(2026, 1, 11),
        versesGoal: 5,
      );
      expect(monday.last.id, 'rot-mon');
      expect(monday.last.kind, DailyTaskKind.manual);
      expect(friday.last.id, 'rot-fri');
      expect(friday.last.title, 'Read Surah Al-Kahf');
      expect(sunday.last.id, 'rot-sun');
    });

    test('a single-ayah goal reads naturally', () {
      final tasks = buildDailyTasks(date: DateTime(2026, 1, 5), versesGoal: 1);
      expect(tasks.first.title, 'Read 1 ayah');
    });

    test('tasks become done from the day\'s record', () {
      final date = DateTime(2026, 1, 5);
      final tasks = buildDailyTasks(date: date, versesGoal: 5);
      final log = blank(date);

      expect(isTaskDone(tasks[0], log, const {}), isFalse);
      final readSome = DayLog(
        date: log.date,
        verses: 4,
        hadiths: 0,
        stories: 0,
        dhikr: 0,
        xp: 0,
        tasks: const {},
        gratitude: '',
      );
      expect(isTaskDone(tasks[0], readSome, const {}), isFalse);
      final readGoal = DayLog(
        date: log.date,
        verses: 5,
        hadiths: 0,
        stories: 0,
        dhikr: 0,
        xp: 0,
        tasks: const {},
        gratitude: '',
      );
      expect(isTaskDone(tasks[0], readGoal, const {}), isTrue);

      // The other kinds key off their own counters.
      expect(isTaskDone(tasks[1], readSome, const {}), isFalse);
      expect(
        isTaskDone(tasks[1], _with(readSome, hadiths: 1), const {}),
        isTrue,
      );
      expect(
        isTaskDone(tasks[2], _with(readSome, dhikr: 99), const {}),
        isFalse,
      );
      expect(
        isTaskDone(tasks[2], _with(readSome, dhikr: 100), const {}),
        isTrue,
      );
      expect(
        isTaskDone(tasks[3], _with(readSome, gratitude: 'rain'), const {}),
        isTrue,
      );
      // Manual tasks live in the tick set.
      expect(isTaskDone(tasks[4], readSome, const {}), isFalse);
      expect(isTaskDone(tasks[4], readSome, const {'rot-mon'}), isTrue);
    });

    test('the all-done bonus arrives only when every task is done', () {
      final date = DateTime(2026, 1, 5);
      final tasks = buildDailyTasks(date: date, versesGoal: 5);
      final partial = _with(blank(date), verses: 5, hadiths: 1, dhikr: 100);
      expect(deservesAllDoneBonus(tasks, partial, const {}), isFalse);
      final nearly = _with(partial, gratitude: 'family');
      expect(deservesAllDoneBonus(tasks, nearly, const {}), isFalse);
      expect(deservesAllDoneBonus(tasks, nearly, const {'rot-mon'}), isTrue);
    });

    test('a day is kept when two tasks are done', () {
      final date = DateTime(2026, 1, 5);
      final tasks = buildDailyTasks(date: date, versesGoal: 5);
      expect(dayIsKept(tasks, blank(date), const {}), isFalse);
      expect(
        dayIsKept(tasks, _with(blank(date), verses: 5), const {}),
        isFalse,
      );
      expect(
        dayIsKept(tasks, _with(blank(date), verses: 5, hadiths: 1), const {}),
        isTrue,
      );
    });
  });

  group('ranks', () {
    test('XP maps to the seven ranks', () {
      expect(rankFor(0).title, 'Seeker');
      expect(rankFor(299).title, 'Seeker');
      expect(rankFor(300).title, 'Learner');
      expect(rankFor(899).title, 'Learner');
      expect(rankFor(900).title, 'Devoted');
      expect(rankFor(12000).title, 'Alim');
      expect(rankFor(999999).title, 'Alim');
    });

    test('progress runs from the current floor to the next', () {
      expect(rankProgress(0), 0);
      expect(rankProgress(150), closeTo(0.5, 0.001));
      expect(rankProgress(900), 0);
      expect(rankProgress(12000), 1);
    });
  });

  group('dhikr', () {
    test('the counter moves 33+33+34', () {
      expect(dhikrPhaseIndex(0), 0);
      expect(dhikrPhaseIndex(32), 0);
      expect(dhikrPhaseIndex(33), 1);
      expect(dhikrPhaseIndex(65), 1);
      expect(dhikrPhaseIndex(66), 2);
      expect(dhikrPhaseIndex(99), 2);
      expect(dhikrInPhase(70), 4);
      expect(dhikrTotal, 100);
      expect(dhikrPhases.map((p) => p.count).reduce((a, b) => a + b), 100);
    });
  });

  group('the day\'s picks', () {
    test('a verse of the day is stable and inside the list', () {
      final a = verseRefOfDay(DateTime(2026, 3, 14));
      final b = verseRefOfDay(DateTime(2026, 3, 14, 23, 59));
      expect(a, b);
      expect(verseOfDayRefs, contains(a));
    });

    test('the greeting is the same salaam at every hour', () {
      expect(greetingFor(DateTime(2026, 1, 1, 3)), 'Peace be upon you');
      expect(greetingFor(DateTime(2026, 1, 1, 9)), 'Peace be upon you');
      expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Peace be upon you');
    });
  });

  group('Arabic search normalization', () {
    test('diacritics and alef forms fold away', () {
      expect(normalizeArabic('الْفَاتِحَةِ'), 'الفاتحه');
      expect(normalizeArabic('إِلَى'), 'الي');
      expect(normalizeArabic('أَنْعَمْتَ'), 'انعمت');
      expect(normalizeArabic('مُوسَى'), 'موسي');
    });
  });

  group('day log parsing', () {
    test('the tasks JSON round-trips', () {
      final log = DayLog.fromMap({
        'date': '2026-01-05',
        'verses': 3,
        'hadiths': 2,
        'stories': 1,
        'dhikr': 50,
        'xp': 80,
        'tasks': '{"rot-mon","gratitude"}',
      });
      expect(log.tasks, {'rot-mon', 'gratitude'});
      expect(log.verses, 3);
      expect(log.xp, 80);
    });
  });
}

DayLog _with(
  DayLog base, {
  int? verses,
  int? hadiths,
  int? stories,
  int? dhikr,
  int? xp,
  String? gratitude,
  Set<String>? tasks,
}) => DayLog(
  date: base.date,
  verses: verses ?? base.verses,
  hadiths: hadiths ?? base.hadiths,
  stories: stories ?? base.stories,
  dhikr: dhikr ?? base.dhikr,
  xp: xp ?? base.xp,
  tasks: tasks ?? base.tasks,
  gratitude: gratitude ?? base.gratitude,
);
