import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/daily.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DhikrScreen extends ConsumerStatefulWidget {
  const DhikrScreen({super.key});

  @override
  ConsumerState<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends ConsumerState<DhikrScreen> {
  int _local = 0;
  int _shown = 0;
  Timer? _flushTimer;
  bool _loaded = false;

  @override
  void dispose() {
    _flushTimer?.cancel();
    _flushPending();
    super.dispose();
  }

  void _flushPending() {
    final pending = _local - _shown;
    if (pending > 0) {
      _shown = _local;
      ref.read(actionsProvider).addDhikr(pending);
    }
  }

  void _tap() {
    HapticFeedback.lightImpact();
    setState(() => _local++);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 700), _flushPending);
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(todayLogProvider).valueOrNull?.dhikr ?? 0;
    if (!_loaded && server > 0) {
      _loaded = true;
      _local = server;
      _shown = server;
    } else if (_local < server) {
      _local = server;
      _shown = server;
    }
    final count = _local.clamp(0, dhikrTotal);
    final phaseIndex = dhikrPhaseIndex(count);
    final phase = dhikrPhases[phaseIndex];
    final inPhase = count - phaseFloor(phaseIndex);
    final done = count >= dhikrTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Dhikr')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AlimSpace.lg),
          child: Column(
            children: [
              const SizedBox(height: AlimSpace.sm),
              Text(
                done
                    ? 'Completed. May it weigh heavy on your scale.'
                    : 'Tap the circle for each count: thirty-three, '
                        'thirty-three, thirty-four.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              ProgressRing(
                value: count / dhikrTotal,
                size: 260,
                stroke: 10,
                color: done ? AlimColors.gold : null,
                child: GestureDetector(
                  onTap: _tap,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AlimColors.card(context),
                      border: Border.all(color: AlimColors.hairlineOf(context)),
                    ),
                    child: AnimatedSwitcher(
                      duration: AlimMotion.quick,
                      child: Column(
                        key: ValueKey(done ? 'done' : phaseIndex),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            done ? '١٠٠' : phase.arabic,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: arabicFamily,
                              fontSize: done ? 44 : 34,
                              color: AlimColors.inkOf(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            done
                                ? 'Allahu Akbar completed'
                                : '${phase.transliteration} · $inPhase/${phase.count}',
                            style: TextStyle(
                              color: AlimColors.mutedOf(context),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AlimCard(
                child: Column(
                  children: [
                    for (final p in dhikrPhases)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              count >=
                                      phaseFloor(dhikrPhases.indexOf(p)) +
                                          p.count
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 19,
                              color:
                                  count >=
                                          phaseFloor(dhikrPhases.indexOf(p)) +
                                              p.count
                                      ? Theme.of(context).colorScheme.primary
                                      : AlimColors.mutedOf(context),
                            ),
                            const SizedBox(width: AlimSpace.sm),
                            Expanded(
                              child: Text(
                                '${p.transliteration} × ${p.count}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              p.meaning,
                              style: TextStyle(
                                color: AlimColors.mutedOf(context),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AlimSpace.md),
              Text(
                '$count / $dhikrTotal today',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
