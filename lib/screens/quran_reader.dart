import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio.dart';
import '../services/audio_downloads.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/quran_ornaments.dart';
import '../widgets/surah_download.dart';
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
  final ScrollController _strip = ScrollController();
  late int _current = widget.surah;
  bool _translation = true;
  bool _transliteration = true;
  bool _stripReady = false;
  final Map<int, int> _tapped = {};

  static const double _stripItemWidth = 78;

  @override
  void initState() {
    super.initState();
    _translation = ref.read(profileProvider).translationOn;
    _transliteration = ref.read(profileProvider).transliterationOn;
  }

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final profile = ref.watch(profileProvider);
    final loaded = ref.watch(surahViewProvider(_current)).valueOrNull;
    final surahs = ref.watch(surahsProvider).valueOrNull ?? const <Surah>[];
    final audio = ref.watch(audioProvider);
    final reciter = ref.watch(activeReciterProvider);
    final downloads = ref.watch(audioDownloadsProvider);
    final manager = ref.watch(audioDownloadsProvider.notifier);
    final downloaded = manager.isSurahDownloaded(reciter.id, _current);
    final task = downloads['${reciter.id}/$_current'];
    final playingHere = audio.surah == _current ? audio.ayah : null;
    final marker =
        playingHere ??
        _tapped[_current] ??
        (_current == widget.surah ? widget.focusAyah : null);
    final first =
        loaded != null && loaded.ayat.isNotEmpty ? loaded.ayat.first : null;
    final local =
        marker == null || loaded == null
            ? null
            : marker - loaded.surah.firstAyah + 1;
    final within =
        local != null && local >= 1 && local <= (loaded?.surah.ayat ?? 0);
    final here = audio.surah == _current && audio.ayah != null;
    final busy = task?.busy ?? false;
    if (!_stripReady && surahs.isNotEmpty) {
      _stripReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollStrip(_current, animate: false);
      });
    }

    final status =
        audio.failed && here
            ? 'Could not play. Tap play to try again.'
            : downloaded
            ? (within ? 'Saved · Ayah $local' : 'Saved offline')
            : busy
            ? (task?.detail ?? 'Saving')
            : here
            ? (audio.playing
                ? (within ? 'Playing ayah $local' : 'Playing')
                : 'Paused')
            : (profile.downloadBeforePlay
                ? 'Downloads before playing'
                : 'Tap play to listen');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        titleSpacing: 0,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: _translation ? 'Hide translation' : 'Show translation',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _translation ? Icons.translate : Icons.translate_outlined,
              size: 20,
              color: _translation ? p.bronze : p.ink,
            ),
            onPressed: () => setState(() => _translation = !_translation),
          ),
          IconButton(
            tooltip:
                _transliteration
                    ? 'Hide transliteration'
                    : 'Show transliteration',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.spellcheck,
              size: 20,
              color: _transliteration ? p.bronze : p.ink,
            ),
            onPressed:
                () => setState(() => _transliteration = !_transliteration),
          ),
          IconButton(
            tooltip: 'Reciter',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.headphones_outlined, size: 20, color: p.ink),
            onPressed: () => showReciterPicker(context, ref),
          ),
          IconButton(
            tooltip:
                downloaded
                    ? 'Saved offline'
                    : (busy ? 'Saving' : 'Download this surah'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              downloaded
                  ? Icons.download_done_rounded
                  : (busy ? Icons.downloading_rounded : Icons.download_rounded),
              size: 20,
              color: downloaded || busy ? p.bronze : p.ink,
            ),
            onPressed:
                loaded == null
                    ? null
                    : () => _downloadPressed(loaded, reciter, downloaded),
          ),
        ],
      ),
      body: Column(
        children: [
          _SurahRail(
            surahs: surahs,
            current: _current,
            controller: _strip,
            width: _stripItemWidth,
            onPick: _goToSurah,
            onPrevious: _current > 1 ? () => _goToSurah(_current - 1) : null,
            onNext: _current < 114 ? () => _goToSurah(_current + 1) : null,
          ),
          if (loaded != null)
            SuraBanner(
              surah: loaded.surah,
              juz: first?.juz,
              page: first?.page,
              playing: here && audio.playing,
              loading: audio.loading && here,
              onPlay: () => _playPressed(loaded, reciter, audio),
            ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: 114,
              onPageChanged: (page) {
                setState(() => _current = page + 1);
                if (page + 2 <= 114) ref.read(surahViewProvider(page + 2));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _scrollStrip(page + 1);
                });
              },
              itemBuilder: (context, index) {
                final surah = index + 1;
                return _SurahBody(
                  key: ValueKey(surah),
                  surah: surah,
                  scale: profile.arabicScale,
                  translation: _translation,
                  transliteration: _transliteration,
                  focusAyah: surah == widget.surah ? widget.focusAyah : null,
                  onTapped: (ayah) {
                    if (_tapped[surah] == ayah) return;
                    setState(() => _tapped[surah] = ayah);
                  },
                  onListen: (ayah) => _listenFrom(surah, ayah, reciter),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          here
              ? _PlayerBar(
                reciter: reciter,
                status: status,
                here: here,
                busy: busy,
                loading: audio.loading && here,
                playing: audio.playing,
                onPick: () => showReciterPicker(context, ref),
                onPlay:
                    loaded == null
                        ? null
                        : () => _playPressed(loaded, reciter, audio),
                onPrevious:
                    here
                        ? () => ref.read(audioProvider.notifier).previous()
                        : null,
                onNext:
                    here ? () => ref.read(audioProvider.notifier).next() : null,
              )
              : null,
    );
  }

  void _goToSurah(int number) {
    if (number < 1 || number > 114 || number == _current) return;
    _pages.animateToPage(
      number - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollStrip(int surah, {bool animate = true}) {
    if (!_strip.hasClients) return;
    final position = _strip.position;
    final target =
        ((surah - 1) * _stripItemWidth -
                (position.viewportDimension - _stripItemWidth) / 2)
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
    if (animate) {
      _strip.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _strip.jumpTo(target);
    }
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

  Future<void> _listenFrom(int surah, int ayah, Reciter reciter) async {
    setState(() => _tapped[surah] = ayah);
    final view = await ref.read(surahViewProvider(surah).future);
    if (!mounted) return;
    await _startListening(view, reciter, startAyah: ayah);
  }

  Future<void> _startListening(
    SurahView view,
    Reciter reciter, {
    int? startAyah,
  }) async {
    final manager = ref.read(audioDownloadsProvider.notifier);
    var directory = manager.surahDirectorySync(reciter.id, view.surah.number);
    if (directory == null && ref.read(profileProvider).downloadBeforePlay) {
      final saved = await showSurahDownloadSheet(
        context,
        reciter: reciter,
        surah: view.surah.number,
        surahName: view.surah.name,
        ayatCount: view.ayat.length,
      );
      if (!mounted) return;
      if (saved == true) {
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
              startAyah ??
              _tapped[view.surah.number] ??
              (view.surah.number == widget.surah ? widget.focusAyah : null),
          localDir: directory,
        );
  }

  Future<void> _downloadPressed(
    SurahView view,
    Reciter reciter,
    bool downloaded,
  ) async {
    if (!downloaded) {
      await showSurahDownloadSheet(
        context,
        reciter: reciter,
        surah: view.surah.number,
        surahName: view.surah.name,
        ayatCount: view.ayat.length,
      );
      return;
    }
    await removeSurahDownload(
      context,
      ref,
      reciter: reciter,
      surah: view.surah,
    );
  }
}

class _SurahRail extends StatelessWidget {
  const _SurahRail({
    required this.surahs,
    required this.current,
    required this.controller,
    required this.width,
    required this.onPick,
    required this.onPrevious,
    required this.onNext,
  });

  final List<Surah> surahs;
  final int current;
  final ScrollController controller;
  final double width;
  final ValueChanged<int> onPick;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    return Container(
      key: const Key('surah-rail'),
      height: 40,
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          _RailArrow(
            key: const Key('previous-surah'),
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous surah',
            onTap: onPrevious,
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemExtent: width,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: surahs.length,
              itemBuilder: (context, i) {
                final surah = surahs[i];
                final active = surah.number == current;
                return InkWell(
                  onTap: () => onPick(surah.number),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? p.bronze : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      surah.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? p.ink : p.muted,
                        fontSize: 11.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _RailArrow(
            key: const Key('next-surah'),
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next surah',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _RailArrow extends StatelessWidget {
  const _RailArrow({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 30,
          height: 40,
          child: Icon(
            icon,
            size: 19,
            color: onTap == null ? p.hairline : p.muted,
          ),
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.reciter,
    required this.status,
    required this.here,
    required this.busy,
    required this.loading,
    required this.playing,
    required this.onPick,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
  });

  final Reciter reciter;
  final String status;
  final bool here;
  final bool busy;
  final bool loading;
  final bool playing;
  final VoidCallback onPick;
  final VoidCallback? onPlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final iconColor = p.isDark ? p.bg : p.surface;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(AlimRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 16,
                            color: p.bronze,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reciter.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (busy) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.4,
                      color: p.bronze,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                _PlayerIcon(
                  icon: Icons.skip_previous_rounded,
                  tooltip: 'Previous ayah',
                  color: here ? p.ink : p.muted,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: playing ? 'Pause recitation' : 'Play recitation',
                  child: Material(
                    color: p.bronze,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPlay,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child:
                              loading
                                  ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: iconColor,
                                    ),
                                  )
                                  : Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 28,
                                    color: iconColor,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _PlayerIcon(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'Next ayah',
                  color: here ? p.ink : p.muted,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerIcon extends StatelessWidget {
  const _PlayerIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 24, color: color),
          ),
        ),
      ),
    );
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
    required this.transliteration,
    required this.onTapped,
    required this.onListen,
    this.focusAyah,
  });

  final int surah;
  final double scale;
  final bool translation;
  final bool transliteration;
  final ValueChanged<int> onTapped;
  final ValueChanged<int> onListen;
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
          loaded.surah.number == 1 || loaded.surah.number == 9 ? 0 : 1;
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
        audio.playing,
        widget.transliteration,
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
    bool audioPlaying,
    bool showTransliteration,
  ) {
    final transliterations =
        ref.watch(quranTransliterationProvider).valueOrNull ??
        const <int, String>{};
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
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: QuranBismillah(),
          );
        }
        final ayah = view.ayat[i - headerCount];
        final focused = widget.focusAyah == ayah.number;
        final active = playingAyah == ayah.number;
        return _AyahTile(
          key: ValueKey(ayah.number),
          ayah: ayah,
          surahName: view.surah.name,
          scale: widget.scale,
          translation: widget.translation,
          transliteration:
              showTransliteration ? (transliterations[ayah.number] ?? '') : '',
          isLastRead: lastRead == ayah.number,
          bookmarked: bookmarkedAyat.contains(ayah.number),
          focused: focused,
          active: active,
          audioPlaying: audioPlaying,
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
            showAyahSheet(
              context,
              ref,
              ayah,
              view.surah.name,
              onListen: () => widget.onListen(ayah.number),
            );
          },
        );
      },
    );
  }
}

/// One ayah: the Arabic line, its Latin transliteration, the English meaning,
/// and the quiet marks that say where the reader stopped.
class _AyahTile extends StatelessWidget {
  const _AyahTile({
    super.key,
    required this.ayah,
    required this.surahName,
    required this.scale,
    required this.translation,
    required this.transliteration,
    required this.isLastRead,
    required this.bookmarked,
    required this.focused,
    required this.active,
    required this.audioPlaying,
    required this.onTap,
  });

  final Ayah ayah;
  final String surahName;
  final double scale;
  final bool translation;
  final String transliteration;
  final bool isLastRead;
  final bool bookmarked;
  final bool focused;
  final bool active;
  final bool audioPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = QuranPalette.of(context);
    final tint =
        active
            ? p.bronze.withValues(alpha: p.isDark ? 0.10 : 0.07)
            : focused
            ? p.surfaceAlt.withValues(alpha: 0.65)
            : Colors.transparent;
    final trimmed = ayah.textAr.trimRight();
    final hasSajdaMark = trimmed.endsWith('۩');
    final arabic =
        hasSajdaMark
            ? trimmed.substring(0, trimmed.length - 1).trimRight()
            : trimmed;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: tint,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: ValueKey('ayah-number-${ayah.number}'),
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.bronzeTint,
                  border: Border.all(color: p.faintBronze),
                ),
                child: Text(
                  '${ayah.ayah}',
                  style: TextStyle(
                    color: p.bronzeDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: arabic),
                          if (ayah.sajda || hasSajdaMark)
                            TextSpan(
                              text: '  ۩',
                              style: TextStyle(
                                fontFamily: arabicFamily,
                                fontSize: 22 * scale,
                                color: p.bronzeDeep,
                              ),
                            ),
                          TextSpan(
                            text: ' ۝${quranDigits(ayah.ayah)}',
                            style: TextStyle(
                              fontFamily: arabicFamily,
                              fontSize: 20 * scale,
                              color: p.bronzeDeep,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: quranFamily,
                        fontFamilyFallback: const [arabicFamily],
                        fontSize: 23 * scale,
                        height: 1.9,
                        color: p.ink,
                      ),
                    ),
                    if (transliteration.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        transliteration,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 12.5,
                          height: 1.45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (translation) ...[
                      const SizedBox(height: 7),
                      Text(
                        ayah.textEn,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: p.translation,
                          fontSize: 16,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$surahName ${ayah.surah}:${ayah.ayah}',
                          style: TextStyle(
                            color: p.latin,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (active)
                          QuranPill(
                            label: audioPlaying ? 'Playing' : 'Paused',
                            icon:
                                audioPlaying
                                    ? Icons.graphic_eq_rounded
                                    : Icons.pause_rounded,
                            color: p.bronze,
                          ),
                        if (bookmarked)
                          Icon(Icons.bookmark, size: 14, color: p.bronze),
                        if (isLastRead)
                          QuranPill(label: 'Your place', color: p.bronze),
                        if (ayah.sajda)
                          const QuranPill(
                            label: 'Sajda',
                            color: AlimColors.rose,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  String surahName, {
  VoidCallback? onListen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => _AyahSheet(ayah: ayah, surahName: surahName, onListen: onListen),
  );
}

class _AyahSheet extends ConsumerWidget {
  const _AyahSheet({
    required this.ayah,
    required this.surahName,
    this.onListen,
  });

  final Ayah ayah;
  final String surahName;
  final VoidCallback? onListen;

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
    return SingleChildScrollView(
      child: SafeArea(
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
            if (onListen != null)
              ListTile(
                leading: Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Listen from here'),
                onTap: () {
                  Navigator.of(context).pop();
                  onListen!();
                },
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
                        await ref
                            .read(actionsProvider)
                            .setLastRead(ayah.number);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Marked as your place.'),
                          ),
                        );
                      },
            ),
            const SizedBox(height: AlimSpace.sm),
          ],
        ),
      ),
    );
  }
}

/// Opens whatever a bookmark points at, waiting for the row to load first so
/// a cold tap never lands on nothing.
Future<void> openBookmark(
  BuildContext context,
  WidgetRef ref,
  Bookmark bookmark,
) async {
  switch (bookmark.kind) {
    case 'ayah':
      final ayah = await ref.read(ayahProvider(bookmark.ref).future);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) =>
                  QuranReaderScreen(surah: ayah.surah, focusAyah: ayah.number),
        ),
      );
    case 'hadith':
      final hadith = await ref.read(hadithByIdProvider(bookmark.ref).future);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HadithDetailScreen(hadith: hadith)),
      );
    case 'story':
      final story = await ref.read(storyProvider(bookmark.ref).future);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
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
                      onTap: () => openBookmark(context, ref, b),
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
}
