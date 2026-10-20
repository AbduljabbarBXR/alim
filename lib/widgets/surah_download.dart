import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/audio.dart';
import '../services/audio_downloads.dart';
import '../services/notifications.dart';
import '../theme.dart';

/// The download window, shared by the surah list and the reader.
Future<bool?> showSurahDownloadSheet(
  BuildContext context, {
  required Reciter reciter,
  required int surah,
  required String surahName,
  required int ayatCount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => _SurahDownloadSheet(
          reciter: reciter,
          surah: surah,
          surahName: surahName,
          ayatCount: ayatCount,
        ),
  );
}

/// Removes a saved surah after a clear question. Returns true when removed.
Future<bool> removeSurahDownload(
  BuildContext context,
  WidgetRef ref, {
  required Reciter reciter,
  required Surah surah,
}) async {
  final remove = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Remove the download?'),
          content: Text(
            '${surah.name} by ${reciter.name} will no longer be available '
            'offline. You can download it again anytime.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AlimColors.rose),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
  );
  if (remove != true) return false;
  await ref
      .read(audioDownloadsProvider.notifier)
      .deleteSurah(reciter.id, surah.number);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Download removed.')));
  }
  return true;
}

class _SurahDownloadSheet extends ConsumerStatefulWidget {
  const _SurahDownloadSheet({
    required this.reciter,
    required this.surah,
    required this.surahName,
    required this.ayatCount,
  });

  final Reciter reciter;
  final int surah;
  final String surahName;
  final int ayatCount;

  @override
  ConsumerState<_SurahDownloadSheet> createState() =>
      _SurahDownloadSheetState();
}

class _SurahDownloadSheetState extends ConsumerState<_SurahDownloadSheet> {
  bool _closed = false;

  String get _key => '${widget.reciter.id}/${widget.surah}';

  @override
  void initState() {
    super.initState();
    unawaited(Notifications.ensureDownloadPermission());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(audioDownloadsProvider.notifier)
          .downloadSurah(widget.reciter, widget.surah);
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = ref.watch(audioDownloadsProvider)[_key];
    if (task?.phase == DownloadPhase.done && !_closed) {
      _closed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
    final failed = task?.phase == DownloadPhase.failed;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          0,
          AlimSpace.lg,
          AlimSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_download_outlined,
                  color: AlimColors.gold,
                ),
                const SizedBox(width: AlimSpace.sm),
                Expanded(
                  child: Text(
                    'Saving ${widget.surahName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.reciter.name} · ${widget.ayatCount} ayat',
              style: TextStyle(
                color: AlimColors.mutedOf(context),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: AlimSpace.md),
            if (failed) ...[
              Text(
                task?.error ?? 'The download stopped.',
                style: const TextStyle(color: AlimColors.rose, fontSize: 13),
              ),
              const SizedBox(height: AlimSpace.sm),
              OutlinedButton(
                onPressed: () {
                  ref
                      .read(audioDownloadsProvider.notifier)
                      .downloadSurah(widget.reciter, widget.surah);
                },
                child: const Text('Try again'),
              ),
            ] else ...[
              LinearProgressIndicator(
                value: task != null && task.progress > 0 ? task.progress : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                task?.detail ?? 'Starting the download',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: AlimSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!failed && (task?.busy ?? false))
                  TextButton(
                    onPressed: () {
                      ref
                          .read(audioDownloadsProvider.notifier)
                          .stopSurah(widget.reciter.id, widget.surah);
                    },
                    child: const Text('Stop saving'),
                  )
                else
                  const SizedBox.shrink(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stream instead'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
