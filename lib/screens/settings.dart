import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/audio.dart';
import '../services/companion.dart';
import '../services/notifications.dart';
import '../state.dart';
import '../theme.dart';
import '../services/prayer.dart';
import '../widgets/common.dart';
import 'companion.dart';
import 'onboarding.dart';
import 'prayer.dart';
import 'qibla.dart';
import 'reciters.dart';

String _translationLabel(WidgetRef ref, String slug) {
  final items = ref.watch(translationsProvider).valueOrNull;
  if (items != null) {
    for (final t in items) {
      if (t.slug == slug) return '${t.translator}, ${t.year}';
    }
  }
  return 'Saheeh International';
}

Future<void> _pickTranslation(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final items = await ref.read(translationsProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AlimSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AlimSpace.lg,
                    0,
                    AlimSpace.lg,
                    AlimSpace.xs,
                  ),
                  child: Text(
                    'English translation',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                for (final t in items)
                  ListTile(
                    leading: Icon(
                      t.slug == profile.translation
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color:
                          t.slug == profile.translation
                              ? AlimColors.gold
                              : AlimColors.mutedOf(sheetContext),
                    ),
                    title: Text(t.title),
                    subtitle: Text('${t.translator}, ${t.year}'),
                    onTap: () async {
                      await ref
                          .read(actionsProvider)
                          .saveProfile(profile.copyWith(translation: t.slug));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AlimSpace.lg,
                    AlimSpace.xs,
                    AlimSpace.lg,
                    0,
                  ),
                  child: Text(
                    'Translations via Tanzil.net, kept verbatim.',
                    style: TextStyle(
                      color: AlimColors.mutedOf(sheetContext),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

String _themeLabel(String mode) {
  switch (mode) {
    case 'light':
      return 'Light, always';
    case 'dark':
      return 'Dark, always';
    default:
      return 'Follow the phone';
  }
}

String _adhanSoundLabel(String sound) =>
    sound == 'long'
        ? 'Adhan, full (2 and a half minutes)'
        : 'Adhan, short (42 seconds)';

Future<void> _rescheduleAdhan(WidgetRef ref, Profile profile) async {
  if (!profile.adhanOn) return;
  final place = ref.read(locationProvider).valueOrNull;
  if (place == null) return;
  await Notifications.scheduleAdhan(
    place: place,
    method: profile.prayerMethod,
    asrHanafi: profile.asrHanafi,
    sound: profile.adhanSound,
    prayers: Notifications.prayersFromCsv(profile.adhanPrayers),
  );
}

Future<void> _toggleAdhan(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
  bool on,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final problem = await ref.read(actionsProvider).setAdhan(on);
  if (problem != null) {
    messenger.showSnackBar(SnackBar(content: Text(problem)));
    return;
  }
  if (on) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('The adhan will sound at each prayer time.'),
      ),
    );
  }
}

Future<void> _toggleAdhanPrayer(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
  AlimPrayer prayer,
  bool on,
) async {
  final chosen = Notifications.prayersFromCsv(profile.adhanPrayers).toSet();
  if (on) {
    chosen.add(prayer);
  } else {
    chosen.remove(prayer);
  }
  final prayers = [
    for (final p in Notifications.adhanPrayers)
      if (chosen.contains(p)) p,
  ];
  if (prayers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Keep at least one prayer, or turn the adhan off.'),
      ),
    );
    return;
  }
  final next = profile.copyWith(
    adhanPrayers: Notifications.prayersToCsv(prayers),
  );
  await ref.read(actionsProvider).saveProfile(next);
  await _rescheduleAdhan(ref, next);
}

Future<void> _pickAdhanSound(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  const options = [
    ('short', 'Adhan, short', 'About 42 seconds'),
    ('long', 'Adhan, full', 'About two and a half minutes'),
  ];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AlimSpace.lg,
                  0,
                  AlimSpace.lg,
                  AlimSpace.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Adhan sound',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  leading: Icon(
                    option.$1 == profile.adhanSound
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        option.$1 == profile.adhanSound
                            ? AlimColors.gold
                            : AlimColors.mutedOf(sheetContext),
                  ),
                  title: Text(option.$2),
                  subtitle: Text(option.$3),
                  trailing: IconButton(
                    tooltip: 'Preview',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () {
                      Notifications.previewAdhan(option.$1);
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'A preview will arrive in a few seconds.',
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () async {
                    final next = profile.copyWith(adhanSound: option.$1);
                    await ref.read(actionsProvider).saveProfile(next);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                    await _rescheduleAdhan(ref, next);
                  },
                ),
              const SizedBox(height: AlimSpace.sm),
            ],
          ),
        ),
  );
}

Future<void> _pickTheme(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  const options = [
    ('system', 'Follow the phone', 'Light or dark, like the rest of Android'),
    ('light', 'Light', 'The parchment palette, day and night'),
    ('dark', 'Dark', 'The night palette, always'),
  ];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AlimSpace.lg,
                  0,
                  AlimSpace.lg,
                  AlimSpace.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Theme',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  leading: Icon(
                    option.$1 == profile.themeMode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        option.$1 == profile.themeMode
                            ? AlimColors.gold
                            : AlimColors.mutedOf(sheetContext),
                  ),
                  title: Text(option.$2),
                  subtitle: Text(option.$3),
                  onTap: () async {
                    await ref
                        .read(actionsProvider)
                        .saveProfile(
                          profile.copyWith(
                            themeMode: option.$1,
                            darkMode: option.$1 == 'dark',
                          ),
                        );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: AlimSpace.sm),
            ],
          ),
        ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final actions = ref.read(actionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          0,
          AlimSpace.lg,
          AlimSpace.xxl,
        ),
        children: [
          const SectionHeader('You'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Name'),
                  subtitle: Text(profile.name),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editName(context, ref, profile),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Daily Qur\'an goal'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AlimSpace.md,
                    0,
                    AlimSpace.md,
                    AlimSpace.sm,
                  ),
                  child: Wrap(
                    spacing: AlimSpace.xs,
                    children: [
                      for (final n in const [2, 5, 10, 20, 30, 50])
                        ChoiceChip(
                          label: Text('$n'),
                          selected: profile.versesGoal == n,
                          onSelected:
                              (_) => actions.saveProfile(
                                profile.copyWith(versesGoal: n),
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Reading'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.translate),
                  title: const Text('English translation'),
                  subtitle: const Text('Beside the Arabic, on every ayah'),
                  value: profile.translationOn,
                  onChanged:
                      (v) => actions.saveProfile(
                        profile.copyWith(translationOn: v),
                      ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Translation'),
                  subtitle: Text(_translationLabel(ref, profile.translation)),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap: () => _pickTranslation(context, ref, profile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('Arabic size'),
                  subtitle: Slider(
                    value: profile.arabicScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: '${(profile.arabicScale * 100).round()}%',
                    onChanged:
                        (v) => actions.saveProfile(
                          profile.copyWith(arabicScale: v),
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Listening'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.headphones_outlined),
                  title: const Text('Reciter'),
                  subtitle: Text(reciterById(profile.reciter).name),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap: () => showReciterPicker(context, ref),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Download before playing'),
                  subtitle: const Text(
                    'Save the surah, then listen without a connection',
                  ),
                  value: profile.downloadBeforePlay,
                  onChanged:
                      (v) => actions.saveProfile(
                        profile.copyWith(downloadBeforePlay: v),
                      ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Browse voices'),
                  subtitle: const Text(
                    'Samples, styles and full offline packs',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecitersScreen(),
                        ),
                      ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.wifi_outlined),
                  title: Text('Streaming audio'),
                  subtitle: Text(
                    'Ayah by ayah from everyayah.com. No download needed.',
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Reminder'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Daily reminder'),
                  subtitle: const Text('One nudge, at the hour you choose'),
                  value: profile.reminderOn,
                  onChanged: (v) async {
                    if (v) {
                      final granted = await Notifications.requestPermission();
                      if (!granted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Android refused the notification permission.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      await Notifications.scheduleDaily(
                        hour: profile.reminderHour,
                        minute: profile.reminderMinute,
                        body:
                            'Your day has a few open pages. Qur\'an, a '
                            'hadith, a dhikr.',
                      );
                    } else {
                      await Notifications.cancelDaily();
                    }
                    await actions.saveProfile(profile.copyWith(reminderOn: v));
                  },
                ),
                if (profile.reminderOn) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Time'),
                    trailing: Text(
                      '${profile.reminderHour.toString().padLeft(2, '0')}:'
                      '${profile.reminderMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: profile.reminderHour,
                          minute: profile.reminderMinute,
                        ),
                      );
                      if (picked != null) {
                        await Notifications.scheduleDaily(
                          hour: picked.hour,
                          minute: picked.minute,
                          body:
                              'Your day has a few open pages. Qur\'an, a '
                              'hadith, a dhikr.',
                        );
                        await actions.saveProfile(
                          profile.copyWith(
                            reminderHour: picked.hour,
                            reminderMinute: picked.minute,
                          ),
                        );
                      }
                    },
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.contrast),
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(profile.themeMode)),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap: () => _pickTheme(context, ref, profile),
                ),
              ],
            ),
          ),
          const SectionHeader('Place and prayer'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Location'),
                  subtitle: Text(
                    ref.watch(locationProvider).valueOrNull == null
                        ? 'Not set. Needed for prayer times and the qibla.'
                        : '${ref.watch(locationProvider).valueOrNull}',
                  ),
                  trailing: const Icon(Icons.my_location, size: 19),
                  onTap: () => acquireLocation(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Prayer times'),
                  subtitle: const Text('Calculated for your coordinates'),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrayerScreen()),
                      ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('Qibla'),
                  subtitle: const Text('A compass to the Kaaba'),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QiblaScreen()),
                      ),
                ),
              ],
            ),
          ),
          const SectionHeader('Adhan'),
          AlimCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.campaign_outlined),
                  title: const Text('Call to prayer'),
                  subtitle: const Text('The adhan sounds at each prayer time'),
                  value: profile.adhanOn,
                  onChanged: (v) => _toggleAdhan(context, ref, profile, v),
                ),
                if (profile.adhanOn) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.music_note_outlined),
                    title: const Text('Adhan sound'),
                    subtitle: Text(_adhanSoundLabel(profile.adhanSound)),
                    trailing: const Icon(Icons.chevron_right, size: 19),
                    onTap: () => _pickAdhanSound(context, ref, profile),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final prayer in Notifications.adhanPrayers)
                          FilterChip(
                            label: Text(prayerLabel(prayer)),
                            selected: Notifications.prayersFromCsv(
                              profile.adhanPrayers,
                            ).contains(prayer),
                            onSelected:
                                (on) => _toggleAdhanPrayer(
                                  context,
                                  ref,
                                  profile,
                                  prayer,
                                  on,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (companionEnabled) ...[
            const SectionHeader('Companion'),
            AlimCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Study companion'),
                subtitle: const Text('Ask about what you are reading'),
                trailing: const Icon(Icons.chevron_right, size: 19),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CompanionScreen(),
                      ),
                    ),
              ),
            ),
          ],
          const SectionHeader('About the sources'),
          AlimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  'Qur\'an: the Uthmani script and four English '
                      'translations (Saheeh International, Pickthall, '
                      'Yusuf Ali, Hilali and Khan) from Tanzil.net, all '
                      '6,236 ayat.',
                  'Hadith: Sahih al-Bukhari, Sahih Muslim, an-Nawawi\'s '
                      'Forty, and the hadith Qudsi, every one of them '
                      'authentic.',
                  'Stories: forty-six tellings written for Alim, each '
                      'anchored to an ayah, and where possible to the '
                      'hadith that carries it.',
                  'Audio: ayah by ayah from everyayah.com. Stream any '
                      'voice, or download a surah or a whole voice for '
                      'offline listening.',
                  'Adhan: two recordings from Wikimedia Commons, both '
                      'released under CC0 by their recorders.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AlimSpace.sm),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader('Danger'),
          AlimCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AlimColors.rose,
              ),
              title: const Text('Erase all my data'),
              subtitle: const Text('Days, bookmarks, tasks and name'),
              onTap: () => _confirmErase(context, ref),
            ),
          ),
        ],
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
            content: TextField(controller: controller, autofocus: true),
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
    if (name != null && name.isNotEmpty) {
      await ref.read(actionsProvider).saveProfile(profile.copyWith(name: name));
    }
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Erase everything?'),
            content: const Text(
              'Every counted ayah, hadith, story, dhikr, bookmark and task will '
              'be gone. The Qur\'an and the hadith stay, of course.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep my data'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AlimColors.rose,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Erase'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await ref.read(storeProvider).eraseUserData();
    await ref.read(actionsProvider).saveProfile(const Profile());
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }
}
