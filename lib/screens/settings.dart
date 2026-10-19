import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/companion.dart';
import '../services/notifications.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'companion.dart';
import 'onboarding.dart';
import 'prayer.dart';
import 'qibla.dart';

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
                          onSelected: (_) => actions.saveProfile(
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
                  subtitle: const Text('Yusuf Ali, beside the Arabic'),
                  value: profile.translationOn,
                  onChanged: (v) =>
                      actions.saveProfile(profile.copyWith(translationOn: v)),
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
                    onChanged: (v) =>
                        actions.saveProfile(profile.copyWith(arabicScale: v)),
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
                        body: 'Your day has a few open pages. Qur\'an, a '
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
                          body: 'Your day has a few open pages. Qur\'an, a '
                              'hadith, a dhikr.',
                        );
                        await actions.saveProfile(profile.copyWith(
                          reminderHour: picked.hour,
                          reminderMinute: picked.minute,
                        ));
                      }
                    },
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('A darker palette for late hours'),
                  value: profile.darkMode,
                  onChanged: (v) =>
                      actions.saveProfile(profile.copyWith(darkMode: v)),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrayerScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: const Text('Qibla'),
                  subtitle: const Text('A compass to the Kaaba'),
                  trailing: const Icon(Icons.chevron_right, size: 19),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QiblaScreen()),
                  ),
                ),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CompanionScreen()),
                ),
              ),
            ),
          ],
          const SectionHeader('About the sources'),          AlimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in const [
                  'Qur\'an: the Uthmani script with the Yusuf Ali '
                      'translation of 1934 (public domain), all 6,236 ayat.',
                  'Hadith: Sahih al-Bukhari, Sahih Muslim, an-Nawawi\'s '
                      'Forty, and the hadith Qudsi, every one of them '
                      'authentic.',
                  'Stories: forty-six tellings written for Alim, each '
                      'anchored to an ayah, and where possible to the '
                      'hadith that carries it.',
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
      builder: (context) => AlertDialog(
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
      await ref
          .read(actionsProvider)
          .saveProfile(profile.copyWith(name: name));
    }
  }

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
