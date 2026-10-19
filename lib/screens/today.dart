import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/daily.dart';
import '../services/prayer.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'dhikr.dart';
import 'hadith.dart';
import 'prayer.dart';
import 'quran_reader.dart';
import 'stories.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final log = ref.watch(todayLogProvider);
    final tasks = ref.watch(todayTasksProvider);
    final stats = ref.watch(statsProvider);
    final lastRead = ref.watch(lastReadProvider);
    final verse = ref.watch(verseOfDayProvider);
    final hadith = ref.watch(hadithOfDayProvider);
    final stories = ref.watch(storiesProvider);
    final now = ref.watch(todayProvider);

    final logValue = log.valueOrNull;
    final taskList = tasks.valueOrNull ?? const <DailyTask>[];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(revisionProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              AlimSpace.sm,
              AlimSpace.lg,
              AlimSpace.xxl,
            ),
            children: [
              _header(context, ref, profile.name, now, stats.valueOrNull),
              const SizedBox(height: AlimSpace.md),
              _tasksCard(context, ref, taskList, logValue),
              const SizedBox(height: AlimSpace.md),
              GratitudeField(initial: logValue?.gratitude ?? ''),
              const SectionHeader('Verse of the day'),
              if (verse.valueOrNull != null)
                _verseCard(context, ref, verse.value!),
              const SectionHeader('Hadith of the day'),
              if (hadith.valueOrNull != null)
                _hadithCard(context, ref, hadith.value!),
              if (lastRead.valueOrNull != null) ...[
                const SectionHeader('Continue reading'),
                _continueCard(context, ref, lastRead.value!),
              ],
              if (stories.valueOrNull != null && stories.value!.isNotEmpty) ...[
                const SectionHeader('A story tonight'),
                _storyCard(context, ref, stories.value!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    String name,
    DateTime now,
    JourneyStats? stats,
  ) {
    final hijri = _hijriLabel(now);
    return StarLattice(
      child: Padding(
        padding: const EdgeInsets.only(top: AlimSpace.lg, bottom: AlimSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Today' : name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hijri,
              style: TextStyle(
                color: AlimColors.mutedOf(context),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: AlimSpace.md),
            Row(
              children: [
                AlimPill(
                  label: '${stats?.streak ?? 0} day streak',
                  icon: Icons.local_fire_department,
                  color: AlimColors.rose,
                ),
                const SizedBox(width: AlimSpace.xs),
                if (stats != null)
                  AlimPill(
                    label: '${rankFor(stats.xp).title} · ${stats.xp} XP',
                    icon: Icons.workspace_premium,
                    color: AlimColors.gold,
                  ),
              ],
            ),
            const SizedBox(height: AlimSpace.sm),
            if (stats != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AlimRadius.pill),
                child: LinearProgressIndicator(
                  value: rankProgress(stats.xp),
                  minHeight: 6,
                  backgroundColor: AlimColors.hairlineOf(context),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(height: AlimSpace.sm),
            _prayerRow(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _prayerRow(BuildContext context, WidgetRef ref) {
    final day = ref.watch(prayerScheduleProvider).valueOrNull;
    final at = day?.timeOf(day.next);
    return AlimCard(
      onTap:
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrayerScreen())),
      padding: const EdgeInsets.symmetric(
        horizontal: AlimSpace.md,
        vertical: AlimSpace.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 17, color: AlimColors.gold),
          const SizedBox(width: AlimSpace.sm),
          Expanded(
            child: Text(
              at == null
                  ? 'Set your place for prayer times and qibla'
                  : '${prayerLabel(day!.next)} at '
                      '${TimeOfDay.fromDateTime(at).format(context)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: AlimColors.mutedOf(context),
          ),
        ],
      ),
    );
  }

  String _hijriLabel(DateTime now) {
    try {
      final h = HijriCalendar.fromDate(now);
      return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} AH';
    } catch (_) {
      return '${now.day}.${now.month}.${now.year}';
    }
  }

  Widget _tasksCard(
    BuildContext context,
    WidgetRef ref,
    List<DailyTask> tasks,
    DayLog? log,
  ) {
    final done =
        log == null
            ? 0
            : tasks.where((t) => isTaskDone(t, log, log.tasks)).length;
    return AlimCard(
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: tasks.isEmpty ? 0 : done / tasks.length,
                size: 52,
                child: Text(
                  '$done/${tasks.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AlimSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s plan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done == tasks.length && tasks.isNotEmpty
                          ? 'All done. A perfect day, alhamdulillah.'
                          : 'Kept days need two done. The rest is mercy.',
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AlimSpace.lg),
          for (final task in tasks)
            _TaskTile(
              task: task,
              done: log == null ? false : isTaskDone(task, log, log.tasks),
              onChanged:
                  (v) => ref.read(actionsProvider).markManualTask(task.id, v),
              onOpen: () => _openTask(context, ref, task),
            ),
        ],
      ),
    );
  }

  void _openTask(BuildContext context, WidgetRef ref, DailyTask task) {
    switch (task.kind) {
      case DailyTaskKind.quran:
        final last = ref.read(lastReadProvider).valueOrNull;
        final ayah =
            last == null
                ? null
                : ref.read(surahOfAyahProvider(last)).valueOrNull;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => QuranReaderScreen(
                  surah: ayah?.number ?? 1,
                  focusAyah: last,
                ),
          ),
        );
      case DailyTaskKind.hadith:
        final hadith = ref.read(hadithOfDayProvider).valueOrNull;
        if (hadith != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HadithDetailScreen(hadith: hadith),
            ),
          );
        }
      case DailyTaskKind.dhikr:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DhikrScreen()));
      case DailyTaskKind.gratitude:
        FocusScope.of(context).requestFocus(_gratitudeFocus);
      case DailyTaskKind.story:
        final stories = ref.read(storiesProvider).valueOrNull;
        if (stories != null && stories.isNotEmpty) {
          final pick =
              stories[ref
                      .read(todayProvider)
                      .difference(DateTime(2026))
                      .inDays %
                  stories.length];
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoryDetailScreen(story: pick)),
          );
        }
      case DailyTaskKind.manual:
        break;
    }
  }

  Widget _verseCard(BuildContext context, WidgetRef ref, Ayah verse) {
    final profile = ref.watch(profileProvider);
    final bookmarked =
        ref.watch(bookmarkAtProvider(('ayah', verse.number))).valueOrNull ??
        false;
    final surah = ref.watch(surahOfAyahProvider(verse.number)).valueOrNull;
    return AlimCard(
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            verse.textAr,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: quranFamily,
              fontSize: 24 * profile.arabicScale,
              height: 1.9,
            ),
          ),
          const SizedBox(height: AlimSpace.sm),
          if (profile.translationOn)
            Text(
              verse.textEn,
              style: const TextStyle(height: 1.6, fontSize: 14.5),
            ),
          const SizedBox(height: AlimSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${surah?.name ?? ''} ${verse.surah}:${verse.ayah}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: bookmarked ? AlimColors.gold : null,
                ),
                onPressed:
                    () => ref
                        .read(actionsProvider)
                        .toggleBookmark(
                          'ayah',
                          verse.number,
                          '${surah?.name ?? 'Qur\'an'} ${verse.surah}:${verse.ayah}',
                        ),
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share, size: 19),
                onPressed:
                    () => Share.share(
                      '${verse.textAr}\n\n${verse.textEn}\nQur\'an ${verse.surah}:${verse.ayah}',
                    ),
              ),
              IconButton(
                tooltip: 'Open in the reader',
                icon: const Icon(Icons.arrow_outward, size: 20),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => QuranReaderScreen(
                              surah: verse.surah,
                              focusAyah: verse.number,
                            ),
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hadithCard(BuildContext context, WidgetRef ref, Hadith hadith) {
    final learnedToday =
        ref.watch(hadithReadSetProvider).valueOrNull?.contains(hadith.id) ??
        false;
    return AlimCard(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HadithDetailScreen(hadith: hadith),
            ),
          ),
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hadith.textEn,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.55, fontSize: 14.5),
          ),
          const SizedBox(height: AlimSpace.sm),
          Row(
            children: [
              AlimPill(
                label: _collectionLabel(hadith.collection),
                color: AlimColors.gold,
                icon: Icons.verified_outlined,
              ),
              const SizedBox(width: AlimSpace.xs),
              Text(
                '#${hadith.numberInBook}',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              if (learnedToday)
                AlimPill(
                  label: 'Learned today',
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.check_circle_outline,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _continueCard(BuildContext context, WidgetRef ref, int lastRead) {
    final surah = ref.watch(surahOfAyahProvider(lastRead)).valueOrNull;
    final inSurah = surah == null ? lastRead : lastRead - surah.firstAyah + 1;
    return AlimCard(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => QuranReaderScreen(
                    surah: surah?.number ?? 1,
                    focusAyah: lastRead,
                  ),
            ),
          ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AlimColors.gold.withValues(alpha: 0.12),
              border: Border.all(
                color: AlimColors.gold.withValues(alpha: 0.40),
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AlimColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: AlimSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surah?.name ?? 'The Qur\'an',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  'Ayah $inSurah · tap to continue',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _storyCard(BuildContext context, WidgetRef ref, List<Story> stories) {
    final pick =
        stories[ref.watch(todayProvider).difference(DateTime(2026)).inDays %
            stories.length];
    return AlimCard(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoryDetailScreen(story: pick)),
          ),
      child: Row(
        children: [
          const Icon(Icons.local_library_outlined, color: AlimColors.gold),
          const SizedBox(width: AlimSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pick.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  '${pick.minutes} min · ${pick.category}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  String _collectionLabel(String id) {
    switch (id) {
      case 'bukhari':
        return 'Sahih al-Bukhari';
      case 'muslim':
        return 'Sahih Muslim';
      case 'nawawi':
        return 'Nawawi 40';
      case 'qudsi':
        return 'Hadith Qudsi';
      default:
        return id;
    }
  }
}

final _gratitudeFocus = FocusNode();

class GratitudeField extends ConsumerStatefulWidget {
  const GratitudeField({super.key, required this.initial});

  final String initial;

  @override
  ConsumerState<GratitudeField> createState() => _GratitudeFieldState();
}

class _GratitudeFieldState extends ConsumerState<GratitudeField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  late String _saved = widget.initial.trim();

  @override
  void initState() {
    super.initState();
    _gratitudeFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _gratitudeFocus.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_gratitudeFocus.hasFocus) _save(quiet: true);
  }

  Future<void> _save({bool quiet = false}) async {
    final text = _controller.text.trim();
    if (text == _saved) {
      if (!quiet) _gratitudeFocus.unfocus();
      return;
    }
    await ref.read(actionsProvider).setGratitude(text);
    if (!mounted) return;
    setState(() => _saved = text);
    if (!quiet) {
      _controller.clear();
      _gratitudeFocus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.isEmpty ? 'Gratitude cleared.' : 'Gratitude saved for today.',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlimCard(
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_outline,
                size: 18,
                color: AlimColors.rose,
              ),
              const SizedBox(width: AlimSpace.xs),
              Text(
                'One line of gratitude',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AlimSpace.xs),
          TextField(
            controller: _controller,
            focusNode: _gratitudeFocus,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Today I am thankful for…',
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (_saved.isEmpty || value.text.trim() == _saved) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AlimSpace.xs),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AlimRadius.field),
                  onTap: () {
                    _controller.text = _saved;
                    _controller.selection = TextSelection.collapsed(
                      offset: _saved.length,
                    );
                    _gratitudeFocus.requestFocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 15,
                          color: AlimColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Saved for today: $_saved',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AlimColors.mutedOf(context),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.done,
    required this.onChanged,
    required this.onOpen,
  });

  final DailyTask task;
  final bool done;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final manual = task.kind == DailyTaskKind.manual;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (manual)
            Checkbox(value: done, onChanged: (v) => onChanged(v ?? false))
          else
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 4),
              child: ProgressRing(
                value: done ? 1 : 0,
                size: 26,
                stroke: 2.6,
                child:
                    done
                        ? Icon(
                          Icons.check,
                          size: 15,
                          color: Theme.of(context).colorScheme.primary,
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          const SizedBox(width: AlimSpace.xs),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AlimRadius.field),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? AlimColors.mutedOf(context) : null,
                      ),
                    ),
                    Text(
                      task.subtitle,
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            '+${task.xp}',
            style: TextStyle(
              color:
                  done
                      ? AlimColors.mutedOf(context)
                      : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
