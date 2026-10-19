import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location.dart';
import '../services/prayer.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Asks for a fix, and says so when nothing answers.
Future<void> acquireLocation(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final place = await ref.read(actionsProvider).locate();
  if (place == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No location yet. Allow location access and try again.',
        ),
      ),
    );
  }
}

class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla'),
        actions: [
          IconButton(
            tooltip: 'Update location',
            icon: const Icon(Icons.my_location),
            onPressed: () => acquireLocation(context, ref),
          ),
        ],
      ),
      body: location.when(
        data: (place) => place == null
            ? _NeedsLocation(onLocate: () => acquireLocation(context, ref))
            : _Compass(place: place),
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NeedsLocation extends StatelessWidget {
  const _NeedsLocation({required this.onLocate});

  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AlimSpace.lg),
      children: [
        EmptyNote(
          text: 'The qibla needs your place. Nothing is stored on a server; '
              'the coordinates stay in this app.',
          icon: Icons.explore_outlined,
        ),
        const SizedBox(height: AlimSpace.md),
        FilledButton.icon(
          onPressed: onLocate,
          icon: const Icon(Icons.my_location),
          label: const Text('Set my location'),
        ),
      ],
    );
  }
}

class _Compass extends ConsumerWidget {
  const _Compass({required this.place});

  final AlimLocation place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qibla = qiblaBearing(place);
    final events = FlutterCompass.events;
    return StreamBuilder<CompassEvent>(
      stream: events ?? Stream<CompassEvent>.empty(),
      builder: (context, snapshot) {
        final heading = snapshot.data?.heading;
        final aligned = heading != null &&
            headingDelta(qibla, heading).abs() < 5;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            AlimSpace.md,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          children: [
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: _dial(context, heading, qibla, aligned),
              ),
            ),
            const SizedBox(height: AlimSpace.lg),
            if (heading == null)
              EmptyNote(
                text: 'No compass reading yet. The qibla is '
                    '${qibla.round()}° from north. Hold the phone flat, or '
                    'follow this bearing with any compass.',
                icon: Icons.explore_off_outlined,
              )
            else ...[
              Text(
                aligned ? 'You are facing the qibla' : 'Turn until the arrow points up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: aligned
                      ? Theme.of(context).colorScheme.primary
                      : AlimColors.mutedOf(context),
                ),
              ),
              const SizedBox(height: AlimSpace.xs),
              Text(
                'The qibla is ${qibla.round()}° from north. Hold the phone '
                'flat and away from metal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _dial(
    BuildContext context,
    double? heading,
    double qibla,
    bool aligned,
  ) {
    final card = AlimColors.card(context);
    final rose = AlimColors.mutedOf(context);
    final gold = AlimColors.gold;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: card,
            border: Border.all(color: AlimColors.hairlineOf(context)),
          ),
        ),
        if (heading != null)
          Transform.rotate(
            angle: -heading * math.pi / 180,
            child: CustomPaint(
              size: const Size.square(300),
              painter: _RosePainter(rose, gold),
            ),
          ),
        Transform.rotate(
          angle: (qibla - (heading ?? 0)) * math.pi / 180,
          child: SizedBox(
            width: 300,
            height: 300,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Kaaba',
                  style: TextStyle(
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                Icon(
                  Icons.navigation,
                  size: 42,
                  color: aligned
                      ? Theme.of(context).colorScheme.primary
                      : AlimColors.inkOf(context),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: card,
            border: Border.all(color: AlimColors.hairlineOf(context)),
          ),
        ),
      ],
    );
  }
}

class _RosePainter extends CustomPainter {
  _RosePainter(this.rose, this.gold);

  final Color rose;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 22;
    final tick = Paint()
      ..color = rose.withValues(alpha: 0.5)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12 - math.pi / 2;
      final major = i % 6 == 0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner = center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - (major ? 12 : 6));
      canvas.drawLine(inner, outer, tick);
    }
    final label = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(size.width / 2 - label.width / 2, 24),
    );
  }

  @override
  bool shouldRepaint(covariant _RosePainter old) =>
      old.rose != rose || old.gold != gold;
}
