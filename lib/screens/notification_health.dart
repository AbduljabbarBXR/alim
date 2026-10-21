import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NotificationHealthScreen extends StatefulWidget {
  const NotificationHealthScreen({super.key});

  @override
  State<NotificationHealthScreen> createState() =>
      _NotificationHealthScreenState();
}

class _NotificationHealthScreenState extends State<NotificationHealthScreen> {
  late Future<NotificationHealth> _health = Notifications.health();

  void _refresh() {
    setState(() {
      _health = Notifications.health();
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _allowNotifications() async {
    final granted = await Notifications.requestPermission();
    _message(
      granted
          ? 'Notification permission is allowed.'
          : 'Android did not allow notifications. Open app settings and allow them.',
    );
    _refresh();
  }

  Future<void> _allowExact() async {
    final granted = await Notifications.requestExactAlarms();
    _message(
      granted
          ? 'Exact alarms are allowed.'
          : 'Exact alarms are still blocked. Open Android settings and allow alarms and reminders.',
    );
    _refresh();
  }

  Future<void> _openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      _message('Could not open Android settings.');
    }
  }

  Future<void> _test({required Duration delay}) async {
    final sent = await Notifications.scheduleTest(delay: delay);
    _message(
      sent
          ? (delay == Duration.zero
              ? 'Test notification sent.'
              : 'Test notification scheduled for one minute from now.')
          : 'The test could not be sent. Allow notifications first.',
    );
    _refresh();
  }

  String _when(DateTime? at) {
    if (at == null) return 'Pending';
    final now = DateTime.now();
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return 'Today $time';
    }
    return '${at.day}/${at.month} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification check'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<NotificationHealth>(
        future: _health,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final health = snapshot.data;
          if (health == null) {
            return const Center(
              child: Text('Notification status is not available.'),
            );
          }
          final next = health.pending.take(6).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              0,
              AlimSpace.lg,
              AlimSpace.xxl,
            ),
            children: [
              const SectionHeader('Status'),
              AlimCard(
                child: Column(
                  children: [
                    _StatusRow(
                      icon:
                          health.enabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                      title: 'Notifications',
                      detail:
                          health.enabled
                              ? 'Allowed by Android'
                              : 'Blocked by Android',
                      ok: health.enabled,
                    ),
                    const Divider(height: 22),
                    _StatusRow(
                      icon:
                          health.exact
                              ? Icons.alarm_on_outlined
                              : Icons.alarm_off_outlined,
                      title: 'Exact alarms',
                      detail:
                          health.exact
                              ? 'On time alarms are allowed'
                              : 'Android may delay reminders',
                      ok: health.exact,
                    ),
                    const Divider(height: 22),
                    _StatusRow(
                      icon: Icons.event_available_outlined,
                      title: 'Scheduled',
                      detail:
                          '${health.pending.length} notification'
                          '${health.pending.length == 1 ? '' : 's'} waiting',
                      ok: health.pending.isNotEmpty,
                    ),
                    if (!health.ready) ...[
                      const Divider(height: 22),
                      Text(
                        'The notification service did not start on this device.',
                        style: TextStyle(
                          color: AlimColors.rose,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!health.enabled) ...[
                const SizedBox(height: AlimSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _allowNotifications,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Allow notifications'),
                  ),
                ),
              ],
              if (!health.exact) ...[
                const SizedBox(height: AlimSpace.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _allowExact,
                    icon: const Icon(Icons.alarm_on_outlined),
                    label: const Text('Allow exact alarms'),
                  ),
                ),
              ],
              const SizedBox(height: AlimSpace.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open Android app settings'),
                ),
              ),
              const SectionHeader('Test it'),
              AlimCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Send a test now'),
                      subtitle: const Text('Checks permission and the channel'),
                      onTap: () => _test(delay: Duration.zero),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Send a test in one minute'),
                      subtitle: const Text(
                        'Keep the app open, then put it in the background',
                      ),
                      onTap: () => _test(delay: const Duration(minutes: 1)),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Next scheduled'),
              if (next.isEmpty)
                AlimCard(
                  child: Text(
                    'Nothing is scheduled yet. Turn on the daily reminder or the adhan, then refresh.',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      height: 1.5,
                      fontSize: 12.5,
                    ),
                  ),
                )
              else
                AlimCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < next.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.schedule, size: 19),
                          title: Text(
                            next[i].title ?? 'Alim',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _when(Notifications.scheduledAt(next[i])),
                            style: TextStyle(
                              color: AlimColors.mutedOf(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SectionHeader('If it still does not arrive'),
              AlimCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xiaomi and HyperOS can stop alarms when the app is in the background.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AlimSpace.xs),
                    Text(
                      'Open Alim in Android settings and enable Autostart. Set Battery saver to No restrictions. Allow alarms and reminders. Then lock Alim in the recent apps screen. If the app is force stopped, Android cancels its alarms until the app is opened again.',
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        height: 1.55,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color =
        ok ? Theme.of(context).colorScheme.primary : AlimColors.rose;
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: AlimSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        AlimPill(label: ok ? 'Ready' : 'Check', color: color),
      ],
    );
  }
}
