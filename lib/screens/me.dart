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
        ref.watch(bookmarksProvider(null)).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
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
            0,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          children: [
            _identity(context, profile, stats),
            const SectionHeader('The journey'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AlimSpace.xs,
              crossAxisSpacing: AlimSpace.xs,
              childAspectRatio: 0.95,
              children: [
                StatTile(
                  value: '${stats?.verses ?? 0}',
                  label: 'Ayat read',
                  arabic: 'آيات',
                ),
                StatTile(
                  value: '${stats?.hadiths ?? 0}',
                  label: 'Hadith learned',
                  arabic: 'حديث',
                ),
                StatTile(
                  value: '${stats?.stories ?? 0}',
                  label: 'Stories read',
                  arabic: 'قصص',
                ),
                StatTile(
                  value: '${stats?.dhikr ?? 0}',
                  label: 'Dhikr',
                  arabic: 'ذكر',
                ),
                StatTile(
                  value: '${stats?.activeDays ?? 0}',
                  label: 'Active days',
                  arabic: 'أيام',
                ),
                StatTile(
                  value: '$bookmarks',
                  label: 'Bookmarks',
                  arabic: 'علامات',
                ),
              ],
            ),
            const SectionHeader('This week'),
            AlimCard(
              child: weekly.every((v) => v == 0)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AlimSpace.md),
                      child: Text(
                        'A quiet week so far. The first counted ayah starts the '
                        'line.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AlimColors.mutedOf(context),
                          height: 1.5,
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 110,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < weekly.length; i++)
                            Expanded(
                              child: _bar(
                                context,
                                weekly[i],
                                i,
                                weekly.reduce((a, b) => a > b ? a : b),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SectionHeader('Badges'),
            AlimCard(
              child: Wrap(
                spacing: AlimSpace.xs,
                runSpacing: AlimSpace.xs,
                children: [
                  for (final b in badges)
                    _badge(
                      context,
                      b,
                      stats == null ? false : b.earned(stats),
                    ),
                ],
              ),
            ),
            const SectionHeader('My corner'),
            AlimCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: const Text('My bookmarks'),
                    subtitle: Text('$bookmarks kept'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookmarksScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.task_alt),
                    title: const Text('My tasks'),
                    subtitle: const Text('The work side of the day'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyTasksScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AlimSpace.md),
            Center(
              child: Text(
                'Alim 1.0.0',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity(BuildContext context, Profile profile, JourneyStats? stats) {
    final rank = rankFor(stats?.xp ?? 0);
    return StarLattice(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AlimSpace.lg),
        child: Row(
          children: [
            StarNumber(number: 8, size: 62, filled: true),
            const SizedBox(width: AlimSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name.isEmpty ? 'Seeker' : profile.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${rank.title} · ${rank.arabic} · ${stats?.xp ?? 0} XP',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AlimSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AlimRadius.pill),
                    child: LinearProgressIndicator(
                      value: rankProgress(stats?.xp ?? 0),
                      minHeight: 6,
                      backgroundColor: AlimColors.hairlineOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AlimSpace.md),
            Column(
              children: [
                AlimPill(
                  label: '${stats?.streak ?? 0}',
                  icon: Icons.local_fire_department,
                  color: AlimColors.rose,
                ),
                const SizedBox(height: 6),
                Text(
                  'best ${stats?.bestStreak ?? 0}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, int value, int index, int max) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AlimColors.mutedOf(context),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: AlimMotion.settle,
            curve: AlimMotion.ease,
            height: max == 0 ? 6 : (10 + 62 * (value / max)),
            decoration: BoxDecoration(
              color: value == 0
                  ? AlimColors.hairlineOf(context)
                  : Theme.of(context).colorScheme.primary.withValues(
                        alpha: 0.35 + 0.65 * (max == 0 ? 0 : value / max),
                      ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            labels[index % 7],
            style: TextStyle(
              fontSize: 11,
              color: AlimColors.mutedOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, AlimBadge badge, bool earned) {
    final gold = earned ? AlimColors.gold : AlimColors.mutedOf(context);
    return Tooltip(
      message: badge.description,
      child: Container(
        width: 74,
        padding: const EdgeInsets.all(AlimSpace.xs),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: earned ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AlimRadius.field),
          border: Border.all(color: gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(
              earned ? Icons.workspace_premium : Icons.lock_outline,
              size: 20,
              color: gold,
            ),
            const SizedBox(height: 5),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: earned ? null : AlimColors.mutedOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
