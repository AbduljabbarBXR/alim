import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/prayer.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'qibla.dart';

class PrayerScreen extends ConsumerWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(prayerScheduleProvider);
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer times'),
        actions: [
          IconButton(
            tooltip: 'Qibla',
            icon: const Icon(Icons.explore_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QiblaScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Update location',
            icon: const Icon(Icons.my_location),
            onPressed: () => acquireLocation(context, ref),
          ),
        ],
      ),
      body: schedule.when(
        data: (day) => day == null
            ? _needsLocation(context, ref)
            : _times(context, ref, day, profile),
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _needsLocation(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AlimSpace.lg),
      children: [
        EmptyNote(
          text: 'Prayer times are worked out from your coordinates. Allow '
              'location once and Alim remembers it on this device.',
          icon: Icons.place_outlined,
        ),
        const SizedBox(height: AlimSpace.md),
        FilledButton.icon(
          onPressed: () => acquireLocation(context, ref),
          icon: const Icon(Icons.my_location),
          label: const Text('Set my location'),
        ),
      ],
    );
  }

  Widget _times(
    BuildContext context,
    WidgetRef ref,
    PrayerDay day,
    Profile profile,
  ) {
    final next = day.next;
    final nextAt = day.timeOf(next);
    final now = DateTime.now();
    final wait = nextAt.difference(now);
    final friday = now.weekday == DateTime.friday;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        AlimSpace.xs,
        AlimSpace.lg,
        AlimSpace.xxl,
      ),
      children: [
        AlimCard(
          color: AlimColors.goldSoft.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1,
          ),
          border: AlimColors.gold.withValues(alpha: 0.35),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: AlimColors.gold),
              const SizedBox(width: AlimSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next prayer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${prayerLabel(next)} at '
                      '${TimeOfDay.fromDateTime(nextAt).format(context)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
              ),
              if (!wait.isNegative)
                Text(
                  wait.inHours >= 1
                      ? 'in ${wait.inHours}h ${wait.inMinutes % 60}m'
                      : 'in ${wait.inMinutes} min',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AlimSpace.sm),
        AlimCard(
          padding: const EdgeInsets.symmetric(vertical: AlimSpace.xs),
          child: Column(
            children: [
              for (final p in AlimPrayer.values)
                _row(
                  context,
                  label: p == AlimPrayer.dhuhr && friday
                      ? 'Jumu\'ah'
                      : prayerLabel(p),
                  at: day.timeOf(p),
                  highlight: p == next,
                  primary: primary,
                ),
            ],
          ),
        ),
        const SizedBox(height: AlimSpace.xs),
        Text(
          'Your place: ${day.place}. Nothing leaves the device.',
          style: TextStyle(
            color: AlimColors.mutedOf(context),
            fontSize: 12,
          ),
        ),
        const SectionHeader('Calculation'),
        AlimCard(
          child: DropdownMenu<String>(
            initialSelection: profile.prayerMethod,
            label: const Text('Method'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final entry in prayerMethods.entries)
                DropdownMenuEntry(value: entry.key, label: entry.value),
            ],
            onSelected: (value) {
              if (value == null) return;
              ref.read(actionsProvider).saveProfile(
                    ref.read(profileProvider).copyWith(prayerMethod: value),
                  );
            },
          ),
        ),
        const SizedBox(height: AlimSpace.sm),
        AlimCard(
          padding: const EdgeInsets.symmetric(horizontal: AlimSpace.sm),
          child: SwitchListTile(
            title: const Text('Hanafi Asr'),
            subtitle: const Text('Asr begins later, at twice the shadow'),
            value: profile.asrHanafi,
            onChanged: (value) => ref.read(actionsProvider).saveProfile(
                  ref.read(profileProvider).copyWith(asrHanafi: value),
                ),
          ),
        ),
        const SizedBox(height: AlimSpace.sm),
        Text(
          'Times are estimates from your coordinates and the chosen method. '
          'For congregation times, follow your local masjid.',
          style: TextStyle(
            color: AlimColors.mutedOf(context),
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AlimSpace.sm),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(actionsProvider).forgetLocation();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location cleared.')),
              );
            }
          },
          icon: const Icon(Icons.location_off_outlined, size: 18),
          label: const Text('Forget my location'),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required DateTime at,
    required bool highlight,
    required Color primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AlimSpace.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? primary : null,
                fontSize: 14.5,
              ),
            ),
          ),
          Text(
            TimeOfDay.fromDateTime(at).format(context),
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          if (highlight) AlimPill(label: 'Next', color: primary),
        ],
      ),
    );
  }
}
