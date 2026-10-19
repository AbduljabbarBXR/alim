import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio.dart';
import '../services/audio_downloads.dart';
import '../services/notifications.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'hadith.dart';
import 'reciters.dart';
import 'stories.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, this.focusAyah});

  final int surah;

  /// Global ayah number to land on when the reader opens.
  final int? focusAyah;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.surah - 1,
  );
  late int _current = widget.surah;
  bool _translation = true;
  final Map<int, int> _tapped = {};

  @override
  void initState() {
    super.initState();
    _translation = ref.read(profileProvider).translationOn;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final view = ref.watch(surahViewProvider(_current));
    final audio = ref.watch(audioProvider);
    final reciter = ref.watch(activeReciterProvider);
    final downloads = ref.watch(audioDownloadsProvider);
    final downloadManager = ref.watch(audioDownloadsProvider.notifier);
    final downloaded = downloadManager.isSurahDownloaded(reciter.id, _current);
    final downloadTask = downloads['${reciter.id}/$_current'];
    final playingHere = audio.surah == _current ? audio.ayah : null;
    final marker =
        playingHere ??
        _tapped[_current] ??
        (_current == widget.surah ? widget.focusAyah : null);

    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink()),
      // One panel carries the surah, the voice and the controls; below it the
      // pages turn under the finger.
      body: Column(
        children: [
          _SurahPanel(
            surah: view.valueOrNull?.surah,
            translation: _translation,
            onToggleTranslation:
                () => setState(() => _translation = !_translation),
            reciter: reciter,
            downloaded: downloaded,
            task: downloadTask,
            audio: audio,
            surahNumber: _current,
            surahFirstAyah: view.valueOrNull?.surah.firstAyah ?? 1,
            surahAyahCount: view.valueOrNull?.surah.ayat ?? 0,
            markerAyah: marker,
            downloadBeforePlay: profile.downloadBeforePlay,
            onPlay:
                view.valueOrNull == null
                    ? null
                    : () => _playPressed(view.value!, reciter, audio),
            onPrevious:
                audio.surah == _current
                    ? () => ref.read(audioProvider.notifier).previous()
                    : null,
            onNext:
                audio.surah == _current
                    ? () => ref.read(audioProvider.notifier).next()
                    : null,
            onChange: () => showReciterPicker(context, ref),
            onDownload:
                view.valueOrNull == null
                    ? null
                    : () => _downloadPressed(view.value!, reciter, downloaded),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: 114,
              onPageChanged: (page) {
                setState(() => _current = page + 1);
                if (page + 2 <= 114) ref.read(surahViewProvider(page + 2));
              },
              itemBuilder: (context, index) {
                final surah = index + 1;
                return _SurahBody(
                  key: ValueKey(surah),
                  surah: surah,
                  scale: profile.arabicScale,
                  translation: _translation,
                  focusAyah: surah == widget.surah ? widget.focusAyah : null,
                  onTapped: (ayah) {
                    if (_tapped[surah] == ayah) return;
                    setState(() => _tapped[surah] = ayah);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _playPressed(SurahView view, Reciter reciter, AudioView audio) {
    if (audio.failed) {
      _startListening(view, reciter);
      return;
    }
    if (audio.surah == view.surah.number && audio.ayah != null) {
      ref.read(audioProvider.notifier).toggle();
      return;
    }
    _startListening(view, reciter);
  }

  Future<void> _startListening(SurahView view, Reciter reciter) async {
    final manager = ref.read(audioDownloadsProvider.notifier);
    var directory = manager.surahDirectorySync(reciter.id, view.surah.number);
    if (directory == null && ref.read(profileProvider).downloadBeforePlay) {
      final choice = await _offerDownload(view, reciter);
      if (choice == null || !mounted) return;
      if (choice) {
        directory = manager.surahDirectorySync(reciter.id, view.surah.number);
      }
    }
    if (!mounted) return;
    await ref
        .read(audioProvider.notifier)
        .toggleSurah(
          surahNumber: view.surah.number,
          surahName: view.surah.name,
          ayat: view.ayat,
          reciter: reciter,
          startAyah:
              _tapped[view.surah.number] ??
              (view.surah.number == widget.surah ? widget.focusAyah : null),
          localDir: directory,
        );
  }

  Future<bool?> _offerDownload(SurahView view, Reciter reciter) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => _DownloadSheet(
            reciter: reciter,
            surah: view.surah.number,
            surahName: view.surah.name,
            ayatCount: view.ayat.length,
          ),
    );
  }

  Future<void> _downloadPressed(
    SurahView view,
    Reciter reciter,
    bool downloaded,
  ) async {
    if (!downloaded) {
      unawaited(Notifications.ensureDownloadPermission());
      await _offerDownload(view, reciter);
      return;
    }
    final remove = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove the download?'),
            content: Text(
              '${view.surah.name} by ${reciter.name} will no longer be '
              'available offline. You can download it again anytime.',
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
    if (remove != true) return;
    await ref
        .read(audioDownloadsProvider.notifier)
        .deleteSurah(reciter.id, view.surah.number);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Download removed.')));
  }
}

/// One surah's page inside the swipeable reader. It owns its scroll position
/// and its watchers, so neighbouring pages stay warm.
class _SurahBody extends ConsumerStatefulWidget {
  const _SurahBody({
    super.key,
    required this.surah,
    required this.scale,
    required this.translation,
    required this.onTapped,
    this.focusAyah,
  });

  final int surah;
  final double scale;
  final bool translation;
  final ValueChanged<int> onTapped;
  final int? focusAyah;

  @override
  ConsumerState<_SurahBody> createState() => _SurahBodyState();
}

class _SurahBodyState extends ConsumerState<_SurahBody> {
  final ItemScrollController _scroll = ItemScrollController();
  bool _announced = false;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(surahViewProvider(widget.surah));
    final lastRead = ref.watch(lastReadProvider).valueOrNull;
    final bookmarkedAyat =
        ref
            .watch(bookmarksProvider('ayah'))
            .valueOrNull
            ?.map((b) => b.ref)
            .toSet() ??
        const <int>{};
    final audio = ref.watch(audioProvider);
    final playingHere = audio.surah == widget.surah ? audio.ayah : null;

    ref.listen<AudioView>(audioProvider, (previous, next) {
      if (next.surah != widget.surah || next.ayah == null) return;
      if (next.ayah == previous?.ayah) return;
      final loaded = view.valueOrNull;
      if (loaded == null || !_scroll.isAttached) return;
      final index = loaded.ayat.indexWhere((a) => a.number == next.ayah);
      if (index < 0) return;
      final header =
          loaded.surah.number == 1 || loaded.surah.number == 9 ? 1 : 2;
      _scroll.scrollTo(
        index: index + header,
        duration: const Duration(milliseconds: 350),
        alignment: 0.25,
      );
    });

    return switch (view) {
      AsyncData(:final value) => _list(
        context,
        value,
        lastRead,
        bookmarkedAyat,
        playingHere,
      ),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _list(
    BuildContext context,
    SurahView view,
    int? lastRead,
    Set<int> bookmarkedAyat,
    int? playingAyah,
  ) {
    final focusIndex =
        widget.focusAyah == null
            ? null
            : view.ayat.indexWhere((a) => a.number == widget.focusAyah);

    final showBismillah = view.surah.number != 1 && view.surah.number != 9;
    final headerCount = showBismillah ? 1 : 0;

    // Landing exactly on a chosen ayah: the list is lazy, so the position is
    // addressed by item index, never by a guessed scroll offset.
    if (focusIndex != null && focusIndex > 0 && !_announced) {
      _announced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${view.surah.name} ${view.ayat[focusIndex].ayah} is '
                'highlighted below.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _scroll,
      initialScrollIndex:
          focusIndex == null || focusIndex <= 0 ? 0 : focusIndex + headerCount,
      initialAlignment: 0.02,
      padding: const EdgeInsets.only(
        top: AlimSpace.sm,
        bottom: AlimSpace.xxl * 2,
      ),
      itemCount: view.ayat.length + headerCount,
      itemBuilder: (context, i) {
        if (showBismillah && i == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(
              AlimSpace.lg,
              0,
              AlimSpace.lg,
              AlimSpace.sm,
            ),
            child: BismillahBand(),
          );
        }
        final ayah = view.ayat[i - headerCount];
        final focused = widget.focusAyah == ayah.number;
        return _AyahTile(
          key: ValueKey(ayah.number),
          ayah: ayah,
          surahName: view.surah.name,
          scale: widget.scale,
          translation: widget.translation,
          alternate: (i - headerCount).isOdd,
          isLastRead: lastRead == ayah.number,
          bookmarked: bookmarkedAyat.contains(ayah.number),
          focused: focused,
          playing: playingAyah == ayah.number,
          onTap: () async {
            widget.onTapped(ayah.number);
            final milestone = await ref
                .read(actionsProvider)
                .markAyahRead(surah: ayah.surah, ayah: ayah.ayah);
            await ref.read(actionsProvider).setLastRead(ayah.number);
            if (!context.mounted) return;
            if (milestone != null) {
              HapticFeedback.mediumImpact();
              showAlimToast(context, milestone);
            }
            showAyahSheet(context, ref, ayah, view.surah.name);
          },
        );
      },
    );
  }
}

/// One ayah in the long merged band: no card of its own, just a stripe that
/// alternates its shade so the eye can hold its place.
class _AyahTile extends StatelessWidget {
  const _AyahTile({
    super.key,
    required this.ayah,
    required this.surahName,
    required this.scale,
    required this.translation,
    required this.alternate,
    required this.isLastRead,
    required this.bookmarked,
    required this.focused,
    required this.playing,
    required this.onTap,
  });

  final Ayah ayah;
  final String surahName;
  final double scale;
  final bool translation;
  final bool alternate;
  final bool isLastRead;
  final bool bookmarked;
  final bool focused;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highlight =
        playing
            ? AlimColors.goldSoft.withValues(alpha: dark ? 0.16 : 0.85)
            : focused
            ? AlimColors.goldSoft.withValues(alpha: dark ? 0.10 : 0.6)
            : null;
    final zebra =
        alternate
            ? (dark
                ? Colors.white.withValues(alpha: 0.035)
                : Colors.black.withValues(alpha: 0.028))
            : Colors.transparent;
    return Material(
      color: highlight ?? zebra,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            AlimSpace.md,
            AlimSpace.lg,
            AlimSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ayah.textAr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: quranFamily,
                  fontSize: 24 * scale,
                  height: 1.9,
                ),
              ),
              if (translation) ...[
                const SizedBox(height: AlimSpace.xs),
                Text(
                  ayah.textEn,
                  style: const TextStyle(height: 1.6, fontSize: 14.5),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '$surahName ${ayah.surah}:${ayah.ayah}',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (bookmarked) ...[
                    const SizedBox(width: AlimSpace.xs),
                    const Icon(
                      Icons.bookmark,
                      size: 14,
                      color: AlimColors.gold,
                    ),
                  ],
                  if (isLastRead) ...[
                    const SizedBox(width: AlimSpace.xs),
                    const AlimPill(label: 'Your place', color: AlimColors.gold),
                  ],
                  if (ayah.sajda) ...[
                    const SizedBox(width: AlimSpace.xs),
                    const AlimPill(label: 'Sajda', color: AlimColors.rose),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahPanel extends StatelessWidget {
  const _SurahPanel({
    required this.surah,
    required this.translation,
    required this.onToggleTranslation,
    required this.reciter,
    required this.downloaded,
    required this.task,
    required this.audio,
    required this.surahNumber,
    required this.surahFirstAyah,
    required this.surahAyahCount,
    required this.markerAyah,
    required this.downloadBeforePlay,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
    required this.onChange,
    required this.onDownload,
  });

  final Surah? surah;
  final bool translation;
  final VoidCallback onToggleTranslation;
  final Reciter reciter;
  final bool downloaded;
  final DownloadTask? task;
  final AudioView audio;
  final int surahNumber;
  final int surahFirstAyah;
  final int surahAyahCount;
  final int? markerAyah;
  final bool downloadBeforePlay;
  final VoidCallback? onPlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onChange;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final local = markerAyah == null ? null : markerAyah! - surahFirstAyah + 1;
    final within = local != null && local >= 1 && local <= surahAyahCount;
    final here = audio.surah == surahNumber && audio.ayah != null;
    final busy = task?.busy ?? false;
    final status =
        audio.failed && here
            ? 'Could not play. Tap play to try again.'
            : downloaded
            ? (within ? 'Saved · Ayah $local' : 'Saved · ready offline')
            : busy
            ? (task?.detail ?? 'Saving')
            : (within
                ? 'Ayah $local · ${downloadBeforePlay ? 'download first' : 'streaming'}'
                : (downloadBeforePlay ? 'Download first' : 'Streaming'));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
        border: Border(
          bottom: BorderSide(color: AlimColors.gold.withValues(alpha: 0.28)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              AlimSpace.sm,
              AlimSpace.sm,
              AlimSpace.xs,
            ),
            child: Row(
              children: [
                StarNumber(
                  number: surah?.number ?? surahNumber,
                  size: 40,
                  filled: true,
                ),
                const SizedBox(width: AlimSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah?.name ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (surah != null)
                        Text(
                          '${surah!.meaning} · ${surah!.ayat} ayat · '
                          '${surah!.revelation}',
                          style: TextStyle(
                            color: AlimColors.mutedOf(context),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  surah?.nameAr ?? '',
                  style: const TextStyle(
                    fontFamily: arabicFamily,
                    fontSize: 22,
                    color: AlimColors.gold,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AlimColors.gold.withValues(alpha: 0.18)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.sm,
              0,
              AlimSpace.xs,
              0,
            ),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AlimRadius.field),
                  onTap: onChange,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.headphones_outlined,
                          size: 17,
                          color: AlimColors.gold,
                        ),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 128),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reciter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AlimColors.mutedOf(context),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip:
                      translation ? 'Hide translation' : 'Show translation',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    translation ? Icons.translate : Icons.translate_outlined,
                    size: 20,
                  ),
                  onPressed: onToggleTranslation,
                ),
                IconButton(
                  tooltip: 'Previous ayah',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_previous, size: 22),
                  onPressed: onPrevious,
                ),
                IconButton(
                  tooltip: here && audio.playing ? 'Pause' : 'Listen',
                  visualDensity: VisualDensity.compact,
                  color: AlimColors.gold,
                  icon:
                      audio.loading && here
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            here && audio.playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            size: 32,
                          ),
                  onPressed: onPlay,
                ),
                IconButton(
                  tooltip: 'Next ayah',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.skip_next, size: 22),
                  onPressed: onNext,
                ),
                IconButton(
                  tooltip:
                      downloaded
                          ? 'Saved offline'
                          : (busy ? 'Downloading' : 'Download this surah'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    downloaded
                        ? Icons.download_done
                        : (busy ? Icons.downloading : Icons.download_outlined),
                    size: 21,
                    color:
                        downloaded
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                  onPressed: onDownload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadSheet extends ConsumerStatefulWidget {
  const _DownloadSheet({
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
  ConsumerState<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends ConsumerState<_DownloadSheet> {
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

/// What a tap on an ayah offers: carry it out, or keep it.
Future<void> showAyahSheet(
  BuildContext context,
  WidgetRef ref,
  Ayah ayah,
  String surahName,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AyahSheet(ayah: ayah, surahName: surahName),
  );
}

class _AyahSheet extends ConsumerWidget {
  const _AyahSheet({required this.ayah, required this.surahName});

  final Ayah ayah;
  final String surahName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarked =
        ref.watch(bookmarkAtProvider(('ayah', ayah.number))).valueOrNull ??
        false;
    final isLastRead = ref.watch(lastReadProvider).valueOrNull == ayah.number;
    final readToday =
        ref
            .watch(readSetProvider)
            .valueOrNull
            ?.contains('${ayah.surah}:${ayah.ayah}') ??
        false;
    final label = '$surahName ${ayah.surah}:${ayah.ayah}';
    return SafeArea(
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (readToday)
                  AlimPill(
                    label: 'Read today',
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icons.check_circle_outline,
                  ),
                if (ayah.sajda) ...[
                  const SizedBox(width: AlimSpace.xs),
                  const AlimPill(label: 'Sajda', color: AlimColors.rose),
                ],
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Share'),
            onTap: () {
              Navigator.of(context).pop();
              Share.share('${ayah.textAr}\n\n${ayah.textEn}\nQur\'an $label');
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Copy'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              await Clipboard.setData(
                ClipboardData(text: '${ayah.textAr}\n\n${ayah.textEn}'),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Ayah copied.')),
              );
            },
          ),
          ListTile(
            leading: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: bookmarked ? AlimColors.gold : null,
            ),
            title: Text(bookmarked ? 'Remove bookmark' : 'Bookmark'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref
                  .read(actionsProvider)
                  .toggleBookmark('ayah', ayah.number, label);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    bookmarked ? 'Bookmark removed.' : 'Bookmarked.',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(
              isLastRead ? Icons.place : Icons.place_outlined,
              color: isLastRead ? AlimColors.gold : null,
            ),
            title: Text(
              isLastRead ? 'This is your place' : 'Mark as last read',
            ),
            onTap:
                isLastRead
                    ? null
                    : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      await ref.read(actionsProvider).setLastRead(ayah.number);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Marked as your place.')),
                      );
                    },
          ),
          const SizedBox(height: AlimSpace.sm),
        ],
      ),
    );
  }
}

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider(_kind));
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AlimSpace.lg),
            child: Row(
              children: [
                for (final entry in const [
                  (null, 'All'),
                  ('ayah', 'Ayat'),
                  ('hadith', 'Hadith'),
                  ('story', 'Stories'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AlimSpace.xs),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _kind == entry.$1,
                      onSelected: (_) => setState(() => _kind = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AlimSpace.sm),
          Expanded(
            child: switch (bookmarks) {
              AsyncData(:final value) when value.isEmpty => const Padding(
                padding: EdgeInsets.all(AlimSpace.lg),
                child: EmptyNote(
                  text:
                      'Nothing kept yet. Bookmark an ayah, a hadith or a '
                      'story and it waits here.',
                  icon: Icons.bookmark_border,
                ),
              ),
              AsyncData(:final value) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AlimSpace.lg,
                  0,
                  AlimSpace.lg,
                  AlimSpace.xxl,
                ),
                itemCount: value.length,
                itemBuilder: (context, i) {
                  final b = value[i];
                  final icon = switch (b.kind) {
                    'ayah' => Icons.menu_book_outlined,
                    'hadith' => Icons.auto_stories_outlined,
                    _ => Icons.local_library_outlined,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AlimSpace.sm),
                    child: AlimCard(
                      onTap: () => _open(context, b),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AlimSpace.md,
                        vertical: AlimSpace.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: AlimColors.gold),
                          const SizedBox(width: AlimSpace.md),
                          Expanded(
                            child: Text(
                              b.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, size: 19),
                            onPressed:
                                () => ref
                                    .read(actionsProvider)
                                    .toggleBookmark(b.kind, b.ref, b.label),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              AsyncError(:final error) => Center(child: Text('$error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Bookmark b) {
    switch (b.kind) {
      case 'ayah':
        final ayah = ref.read(ayahProvider(b.ref)).valueOrNull;
        if (ayah != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => QuranReaderScreen(
                    surah: ayah.surah,
                    focusAyah: ayah.number,
                  ),
            ),
          );
        }
      case 'hadith':
        final hadith = ref.read(hadithByIdProvider(b.ref)).valueOrNull;
        if (hadith != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HadithDetailScreen(hadith: hadith),
            ),
          );
        }
      case 'story':
        final story = ref.read(storyProvider(b.ref)).valueOrNull;
        if (story != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
          );
        }
    }
  }
}
