import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/daily.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quran_reader.dart';
import 'settings.dart';
import 'todos.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final stats = ref.watch(statsProvider).valueOrNull;
    final weekly = ref.watch(weeklyProvider).valueOrNull ?? const <int>[];
    final bookmarks =
        stats?.bookmarks ??
        ref.watch(bookmarksProvider(null)).valueOrNull?.length ??
        0;
    final openTasks =
        ref
            .watch(todoProvider)
            .valueOrNull
            ?.where((todo) => !todo.done)
            .length ??
        0;
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final now = ref.watch(todayProvider);
    final earned =
        stats == null ? 0 : badges.where((badge) => badge.earned(stats)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
          ),
        ],
      ),
      body: RefreshIndicator(
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
            _hero(
              context,
              profile,
              stats,
              () => _editName(context, ref, profile),
            ),
            SectionHeader(
              'Your journey',
              trailing: Text(
                '${stats?.perfectDays ?? 0} perfect days',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _JourneyCard(stats: stats),
            SectionHeader(
              'This week',
              trailing: Text(
                '${weekly.fold<int>(0, (a, b) => a + b)} ayat',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _WeekCard(weekly: weekly, now: now),
            SectionHeader(
              'Badges',
              trailing: Text(
                stats == null ? '' : '$earned of ${badges.length} earned',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _BadgeShelf(stats: stats),
            const SectionHeader('My corner'),
            AlimCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CornerRow(
                    icon: Icons.bookmarks_outlined,
                    title: 'My bookmarks',
                    subtitle:
                        bookmarks == 0
                            ? 'Verses, hadith and stories you keep'
                            : '$bookmarks kept',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookmarksScreen(),
                          ),
                        ),
                  ),
                  const _CornerLine(),
                  _CornerRow(
                    icon: Icons.task_alt_rounded,
                    title: 'My tasks',
                    subtitle:
                        openTasks == 0
                            ? 'The work side of the day'
                            : '$openTasks open',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyTasksScreen(),
                          ),
                        ),
                  ),
                  const _CornerLine(),
                  _CornerRow(
                    icon: Icons.tune_rounded,
                    title: 'Settings',
                    subtitle: 'Reading, reminders and appearance',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AlimSpace.lg),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        size: 14,
                        color: AlimColors.gold.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Alim ${info?.version ?? '1.4.4'}',
                        style: TextStyle(
                          color: AlimColors.mutedOf(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free. Offline. No account.',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    Profile profile,
    JourneyStats? stats,
    VoidCallback onEdit,
  ) {
    final rank = rankFor(stats?.xp ?? 0);
    final index = ranks.indexOf(rank);
    final next = index < ranks.length - 1 ? ranks[index + 1] : null;
    final progress = rankProgress(stats?.xp ?? 0);
    final name = profile.name.trim().isEmpty ? 'Seeker' : profile.name.trim();
    final monogram = _monogram(name);
    const goldSoft = AlimColors.goldSoft;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AlimRadius.card),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B3A2C), Color(0xFF06251D)],
          ),
          border: Border.all(
            color: AlimColors.gold.withValues(alpha: 0.48),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AlimRadius.card),
        ),
        child: StarLattice(
          rows: 2,
          child: Stack(
            children: [
              Positioned(
                right: -36,
                top: -34,
                child: Icon(
                  Icons.star_outline_rounded,
                  size: 156,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroPill(
                          icon: Icons.local_fire_department_rounded,
                          label: '${stats?.streak ?? 0} day streak',
                          color: const Color(0xFFF3C1B8),
                        ),
                        _HeroPill(
                          icon: Icons.bolt_rounded,
                          label: '${_number(stats?.xp ?? 0)} XP',
                          color: goldSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: goldSoft.withValues(alpha: 0.34),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            alignment: Alignment.center,
                            child:
                                monogram.isEmpty
                                    ? Icon(
                                      Icons.person_outline_rounded,
                                      size: 30,
                                      color: goldSoft,
                                    )
                                    : Text(
                                      monogram,
                                      style: TextStyle(
                                        color: goldSoft,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        color: const Color(0xFFFBF6EA),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Edit name',
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 30,
                                      height: 30,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: goldSoft.withValues(alpha: 0.8),
                                    ),
                                    onPressed: onEdit,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${rank.title} · ${rank.arabic}',
                                style: TextStyle(
                                  fontFamily: arabicFamily,
                                  color: goldSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AlimRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: goldSoft,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            next == null
                                ? 'The highest rank'
                                : '${(progress * 100).round()}% to ${next.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          next == null
                              ? '${_number(stats?.xp ?? 0)} XP'
                              : '${_number(next.floor - (stats?.xp ?? 0))} XP to go',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('What should Alim call you?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(actionsProvider).saveProfile(profile.copyWith(name: name));
    }
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AlimRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.stats});

  final JourneyStats? stats;

  @override
  Widget build(BuildContext context) {
    return AlimCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _cell(
                  context,
                  Icons.menu_book_outlined,
                  _number(stats?.verses ?? 0),
                  'Ayat read',
                ),
              ),
              const _JourneyLine(),
              Expanded(
                child: _cell(
                  context,
                  Icons.auto_stories_outlined,
                  _number(stats?.hadiths ?? 0),
                  'Hadith',
                ),
              ),
              const _JourneyLine(),
              Expanded(
                child: _cell(
                  context,
                  Icons.local_library_outlined,
                  _number(stats?.stories ?? 0),
                  'Stories',
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              Expanded(
                child: _cell(
                  context,
                  Icons.auto_awesome_rounded,
                  _number(stats?.dhikr ?? 0),
                  'Dhikr',
                ),
              ),
              const _JourneyLine(),
              Expanded(
                child: _cell(
                  context,
                  Icons.calendar_month_outlined,
                  _number(stats?.activeDays ?? 0),
                  'Active days',
                ),
              ),
              const _JourneyLine(),
              Expanded(
                child: _cell(
                  context,
                  Icons.bookmark_border_rounded,
                  _number(stats?.bookmarks ?? 0),
                  'Bookmarks',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AlimColors.mutedOf(context),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AlimColors.hairlineOf(context).withValues(alpha: 0.7),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.weekly, required this.now});

  final List<int> weekly;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (weekly.isEmpty) {
      return AlimCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }
    if (weekly.every((value) => value == 0)) {
      return AlimCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AlimSpace.md),
          child: Text(
            'A quiet week so far. The first counted ayah starts the line.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              height: 1.5,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }
    final max = weekly.reduce((a, b) => a > b ? a : b);
    final active = weekly.where((value) => value > 0).length;
    return AlimCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weekly.length; i++)
                  Expanded(
                    child: _bar(
                      context,
                      weekly[i],
                      _dayInitial(
                        now.subtract(Duration(days: weekly.length - 1 - i)),
                      ),
                      i == weekly.length - 1,
                      max,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(
                Icons.wb_twilight_rounded,
                size: 14,
                color: AlimColors.gold.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                '$active of 7 days with Qur\'an',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    int value,
    String label,
    bool today,
    int max,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = AlimColors.mutedOf(context);
    final fill =
        value == 0
            ? AlimColors.hairlineOf(context)
            : today
            ? primary
            : primary.withValues(alpha: 0.35 + 0.55 * (value / max));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: today ? primary : muted,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: AlimMotion.settle,
            curve: AlimMotion.ease,
            width: 17,
            height: 8 + 58 * (value / max),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: today ? FontWeight.w800 : FontWeight.w400,
              color: today ? primary : muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeShelf extends StatelessWidget {
  const _BadgeShelf({required this.stats});

  final JourneyStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return AlimCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }
    final earned = badges.where((badge) => badge.earned(stats!)).toList();
    final locked = badges.where((badge) => !badge.earned(stats!)).toList();
    final ordered = [...earned, ...locked];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: ordered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final badge = ordered[i];
          return _BadgeTile(badge: badge, earned: i < earned.length);
        },
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});

  final AlimBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final gold = AlimColors.gold;
    final muted = AlimColors.mutedOf(context);
    final color = earned ? gold : muted;
    return Tooltip(
      message: badge.description,
      child: Container(
        width: 86,
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
        decoration: BoxDecoration(
          color:
              earned
                  ? gold.withValues(alpha: 0.10)
                  : AlimColors.card(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AlimRadius.field),
          border: Border.all(
            color:
                earned
                    ? gold.withValues(alpha: 0.42)
                    : AlimColors.hairlineOf(context),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: earned ? 0.15 : 0.08),
              ),
              child: Icon(
                earned
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: earned ? null : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerRow extends StatelessWidget {
  const _CornerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AlimColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: AlimColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AlimColors.mutedOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerLine extends StatelessWidget {
  const _CornerLine();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 12,
      color: AlimColors.hairlineOf(context).withValues(alpha: 0.7),
    );
  }
}

String _monogram(String name) {
  final parts =
      name
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _dayInitial(DateTime date) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

String _number(int value) {
  final text = '$value';
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
