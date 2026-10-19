import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location.dart';
import '../services/prayer.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Asks for a fix, and says exactly what is missing when nothing answers.
Future<void> acquireLocation(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(actionsProvider).locate();
  } on LocationProblemException catch (problem) {
    if (!context.mounted) return;
    switch (problem.problem) {
      case LocationProblem.serviceOff:
        final open = await _offerSettings(
          context,
          title: 'Location is turned off',
          body:
              'Alim needs this phone\'s location for prayer times and the '
              'qibla. Turn it on, then come back.',
        );
        if (open) await Geolocator.openLocationSettings();
      case LocationProblem.blocked:
        final open = await _offerSettings(
          context,
          title: 'Location is blocked',
          body:
              'Location was blocked for Alim. Allow it in the app settings, '
              'then come back.',
        );
        if (open) await Geolocator.openAppSettings();
      case LocationProblem.denied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location was not allowed. Alim needs it for prayer times and '
              'the qibla.',
            ),
          ),
        );
      case LocationProblem.unavailable:
        messenger.showSnackBar(
          SnackBar(
            content: const Text('No fix yet. Step outside or try again.'),
            action: SnackBarAction(
              label: 'Try again',
              onPressed: () => acquireLocation(context, ref),
            ),
          ),
        );
    }
  }
}

Future<bool> _offerSettings(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
  );
  return answer ?? false;
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
        data:
            (place) =>
                place == null
                    ? _NeedsLocation(
                      onLocate: () => acquireLocation(context, ref),
                    )
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
          text:
              'The qibla needs your place. Nothing is stored on a server; '
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

class _Compass extends StatefulWidget {
  const _Compass({required this.place});

  final AlimLocation place;

  @override
  State<_Compass> createState() => _CompassState();
}

class _CompassState extends State<_Compass> {
  StreamSubscription<CompassEvent>? _sub;
  Timer? _ticker;
  double? _target;
  double? _heading;
  double? _accuracy;
  bool _aligned = false;

  @override
  void initState() {
    super.initState();
    _sub = FlutterCompass.events?.listen(_onEvent);
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _step());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _onEvent(CompassEvent event) {
    final heading = event.heading;
    if (heading == null) return;
    _target = heading;
    _accuracy = event.accuracy;
    if (_heading == null) setState(() => _heading = heading);
  }

  void _step() {
    final target = _target;
    final current = _heading;
    if (target == null) return;
    if (current == null) {
      setState(() => _heading = target);
      return;
    }
    var delta = (target - current) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final next = (current + delta * 0.14) % 360;
    final off = headingDelta(qiblaBearing(widget.place), next).abs();
    final aligned = off < 5 ? true : (off > 10 ? false : _aligned);
    if (delta.abs() < 0.02 && aligned == _aligned) return;
    setState(() {
      _heading = next;
      _aligned = aligned;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qibla = qiblaBearing(widget.place);
    final heading = _heading;
    final km = _distanceKm(widget.place);
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
            child: _dial(context, heading, qibla, _aligned),
          ),
        ),
        const SizedBox(height: AlimSpace.lg),
        if (heading == null)
          EmptyNote(
            text:
                'No compass reading yet. The qibla is '
                '${qibla.round()}° from north. Hold the phone flat, or '
                'follow this bearing with any compass.',
            icon: Icons.explore_off_outlined,
          )
        else ...[
          Text(
            _aligned
                ? 'You are facing the qibla'
                : 'Turn until the arrow points up',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color:
                  _aligned
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
          const SizedBox(height: AlimSpace.sm),
          Text(
            'About ${_km(km)} to the Kaaba, as the crow flies.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              fontSize: 12.5,
            ),
          ),
          if (_accuracy != null && _accuracy! > 15) ...[
            const SizedBox(height: AlimSpace.md),
            Container(
              padding: const EdgeInsets.all(AlimSpace.md),
              decoration: BoxDecoration(
                color: AlimColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AlimRadius.card),
                border: Border.all(
                  color: AlimColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.threesixty, size: 20, color: AlimColors.gold),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compass accuracy is low. Move the phone in a figure 8 '
                      'until the reading settles.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  double _distanceKm(AlimLocation place) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    const earth = 6371.0;
    final dLat = (kaabaLat - place.latitude) * math.pi / 180;
    final dLng = (kaabaLng - place.longitude) * math.pi / 180;
    final lat1 = place.latitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.sqrt(a.toDouble()));
  }

  String _km(double km) {
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    final text = km.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return '${buffer.toString()} km';
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
                  color:
                      aligned
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
    final tick =
        Paint()
          ..color = rose.withValues(alpha: 0.5)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12 - math.pi / 2;
      final major = i % 6 == 0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner =
          center +
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
    label.paint(canvas, Offset(size.width / 2 - label.width / 2, 24));
  }

  @override
  bool shouldRepaint(covariant _RosePainter old) =>
      old.rose != rose || old.gold != gold;
}
