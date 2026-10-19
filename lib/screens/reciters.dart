import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio.dart';
import '../services/audio_downloads.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showReciterPicker(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (sheetContext) => Consumer(
          builder: (sheetContext, ref, _) {
            final profile = ref.watch(profileProvider);
            final downloads = ref.watch(audioDownloadsProvider.notifier);
            return SafeArea(
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
                        'Reciter',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    for (final reciter in reciters)
                      ListTile(
                        leading: Icon(
                          reciter.id == profile.reciter
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color:
                              reciter.id == profile.reciter
                                  ? AlimColors.gold
                                  : AlimColors.mutedOf(sheetContext),
                        ),
                        title: Text(reciter.name),
                        subtitle: Text(
                          '${reciter.style} · ${reciter.kbps} kbps'
                          '${downloads.packDownloaded(reciter.id) ? ' · downloaded pack' : ''}',
                        ),
                        onTap: () async {
                          await ref
                              .read(actionsProvider)
                              .saveProfile(
                                profile.copyWith(reciter: reciter.id),
                              );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const Text('Browse all voices'),
                      subtitle: const Text(
                        'Hear a sample, then download a whole voice',
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 19),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RecitersScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class RecitersScreen extends ConsumerStatefulWidget {
  const RecitersScreen({super.key});

  @override
  ConsumerState<RecitersScreen> createState() => _RecitersScreenState();
}

class _RecitersScreenState extends ConsumerState<RecitersScreen> {
  final AudioPlayer _preview = AudioPlayer();
  StreamSubscription<PlayerState>? _previewSub;
  String? _sampling;

  @override
  void initState() {
    super.initState();
    _previewSub = _preview.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() => _sampling = null);
      }
    });
  }

  @override
  void dispose() {
    _previewSub?.cancel();
    _preview.dispose();
    super.dispose();
  }

  Future<void> _sample(Reciter reciter) async {
    if (_sampling == reciter.id) {
      await _preview.stop();
      if (mounted) setState(() => _sampling = null);
      return;
    }
    await ref.read(audioProvider.notifier).stop();
    setState(() => _sampling = reciter.id);
    try {
      await _preview.setAudioSource(
        AudioSource.uri(Uri.parse(ayahAudioUrl(reciter, 1, 1)), tag: null),
      );
      await _preview.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sampling = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The sample did not play. Check the connection.'),
        ),
      );
    }
  }

  Future<void> _select(Reciter reciter) async {
    final profile = ref.read(profileProvider);
    await ref
        .read(actionsProvider)
        .saveProfile(profile.copyWith(reciter: reciter.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${reciter.name} is now your reciter.')),
    );
  }

  Future<void> _download(Reciter reciter, DownloadTask? task) async {
    final downloads = ref.read(audioDownloadsProvider.notifier);
    if (task?.busy ?? false) {
      await downloads.stopPack(reciter.id);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Download the whole voice?'),
            content: const Text(
              'Every surah will be saved inside Alim, so you can listen '
              'without a connection. A full voice is large, uses a lot of '
              'space, and is best started on Wi-Fi. You can delete it later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Download'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await downloads.downloadPack(reciter);
  }

  Future<void> _delete(Reciter reciter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete this voice?'),
            content: Text(
              'The downloaded surahs of ${reciter.name} will be removed. '
              'You can download them again anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AlimColors.rose),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    await ref.read(audioDownloadsProvider.notifier).deletePack(reciter.id);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final tasks = ref.watch(audioDownloadsProvider);
    final downloads = ref.watch(audioDownloadsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Voices')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          0,
          AlimSpace.lg,
          AlimSpace.xxl,
        ),
        children: [
          Text(
            'Recordings come from everyayah.com. Stream any voice ayah by '
            'ayah, or download a whole voice for offline listening.',
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          for (final reciter in reciters)
            _voiceCard(reciter, profile.reciter, tasks, downloads),
        ],
      ),
    );
  }

  Widget _voiceCard(
    Reciter reciter,
    String selected,
    Map<String, DownloadTask> tasks,
    AudioDownloads downloads,
  ) {
    final task = tasks['${reciter.id}/all'] ?? tasks[reciter.id];
    final done = downloads.downloadedCount(reciter.id);
    final whole = downloads.packDownloaded(reciter.id);
    final busy = task?.busy ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: AlimSpace.sm),
      child: AlimCard(
        padding: const EdgeInsets.all(AlimSpace.md),
        onTap: () => _select(reciter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  reciter.id == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color:
                      reciter.id == selected
                          ? AlimColors.gold
                          : AlimColors.mutedOf(context),
                ),
                const SizedBox(width: AlimSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reciter.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${reciter.style} · ${reciter.kbps} kbps'
                        '${whole ? ' · downloaded pack' : (done > 0 ? ' · $done of 114 saved' : '')}',
                        style: TextStyle(
                          color: AlimColors.mutedOf(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _sampling == reciter.id ? 'Stop sample' : 'Sample',
                  icon: Icon(
                    _sampling == reciter.id
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  color: AlimColors.gold,
                  onPressed: () => _sample(reciter),
                ),
              ],
            ),
            if (task != null &&
                (busy || task.phase == DownloadPhase.failed)) ...[
              const SizedBox(height: AlimSpace.sm),
              LinearProgressIndicator(
                value: busy && task.progress > 0 ? task.progress : null,
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.phase == DownloadPhase.failed
                          ? (task.error ?? 'The download stopped.')
                          : (task.detail ?? 'Downloading'),
                      style: TextStyle(
                        color:
                            task.phase == DownloadPhase.failed
                                ? AlimColors.rose
                                : AlimColors.mutedOf(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  if (busy)
                    TextButton(
                      onPressed: () => downloads.stopPack(reciter.id),
                      child: const Text('Stop'),
                    ),
                  if (task.phase == DownloadPhase.failed)
                    TextButton(
                      onPressed: () => downloads.downloadPack(reciter),
                      child: const Text('Resume'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AlimSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    whole
                        ? 'Ready offline'
                        : (done > 0
                            ? 'Part of this voice is saved'
                            : 'Streaming only'),
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (whole)
                  IconButton(
                    tooltip: 'Delete download',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _delete(reciter),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _download(reciter, task),
                    icon: Icon(
                      busy
                          ? Icons.stop
                          : (done > 0
                              ? Icons.downloading
                              : Icons.download_outlined),
                      size: 18,
                    ),
                    label: Text(
                      busy
                          ? 'Stop'
                          : (done > 0 ? 'Continue pack' : 'Download pack'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
