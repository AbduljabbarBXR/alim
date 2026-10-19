import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/notifications.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _name = TextEditingController();
  int _step = 0;
  int _goal = 5;
  bool _reminderOn = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A name to call you by, even a short one.'),
        ),
      );
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      _controller.animateToPage(
        _step,
        duration: AlimMotion.settle,
        curve: AlimMotion.ease,
      );
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    final profile = Profile(
      name: _name.text.trim(),
      versesGoal: _goal,
      reminderOn: _reminderOn,
      reminderHour: _reminderTime.hour,
      reminderMinute: _reminderTime.minute,
    );
    await ref.read(actionsProvider).saveProfile(profile);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    if (_reminderOn) {
      unawaited(_setupReminder(profile));
    }
  }

  /// Asking the system for permission can wait; the person should not.
  Future<void> _setupReminder(Profile profile) async {
    final granted = await Notifications.requestPermission();
    if (!granted) {
      await ref
          .read(actionsProvider)
          .saveProfile(profile.copyWith(reminderOn: false));
      return;
    }
    await Notifications.scheduleDaily(
      hour: _reminderTime.hour,
      minute: _reminderTime.minute,
      body: 'Your day has a few open pages. Qur\'an, a hadith, a dhikr.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [_welcome(), _goalStep(), _reminderStep()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AlimSpace.lg),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () {
                        setState(() => _step--);
                        _controller.animateToPage(
                          _step,
                          duration: AlimMotion.settle,
                          curve: AlimMotion.ease,
                        );
                      },
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_step == 2 ? 'Begin' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.all(AlimSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          StarNumber(number: 1, size: 64, filled: true),
          const SizedBox(height: AlimSpace.lg),
          Text(
            'Alim',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          Text(
            'عالم',
            style: TextStyle(
              fontFamily: arabicFamily,
              fontSize: 26,
              color: AlimColors.gold,
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          Text(
            'Your deen and your day, together. A mosque lamp of an app: the '
            'Qur\'an with your place kept, authentic hadith, stories of the '
            'earlier ones, and a small honest plan for every day.',
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              height: 1.6,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: AlimSpace.xl),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'What should Alim call you?',
              hintText: 'Your name or kunya',
            ),
            onSubmitted: (_) => _next(),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _goalStep() {
    const options = [2, 5, 10, 20, 30];
    return Padding(
      padding: const EdgeInsets.all(AlimSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'A daily portion of Qur\'an',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AlimSpace.xs),
          Text(
            'Small and constant beats large and rare. You can change this '
            'any time.',
            style: TextStyle(color: AlimColors.mutedOf(context), height: 1.5),
          ),
          const SizedBox(height: AlimSpace.lg),
          Wrap(
            spacing: AlimSpace.sm,
            runSpacing: AlimSpace.sm,
            children: [
              for (final n in options)
                ChoiceChip(
                  label: Text('$n ${n == 1 ? 'ayah' : 'ayat'}'),
                  selected: _goal == n,
                  onSelected: (_) => setState(() => _goal = n),
                ),
            ],
          ),
          const SizedBox(height: AlimSpace.lg),
          AlimCard(
            child: Row(
              children: [
                const Icon(
                  Icons.local_florist_outlined,
                  color: AlimColors.gold,
                ),
                const SizedBox(width: AlimSpace.sm),
                Expanded(
                  child: Text(
                    'Five ayat a day is a sûrah in a little over a week.',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _reminderStep() {
    return Padding(
      padding: const EdgeInsets.all(AlimSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            'One quiet reminder a day',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AlimSpace.xs),
          Text(
            'No noise, no guilt. A single nudge at the time you choose.',
            style: TextStyle(color: AlimColors.mutedOf(context), height: 1.5),
          ),
          const SizedBox(height: AlimSpace.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder'),
            value: _reminderOn,
            onChanged: (v) => setState(() => _reminderOn = v),
          ),
          if (_reminderOn)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              trailing: Text(
                _reminderTime.format(context),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () async {
                final picked = await showAlimTimePicker(context, _reminderTime);
                if (picked != null) setState(() => _reminderTime = picked);
              },
            ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
