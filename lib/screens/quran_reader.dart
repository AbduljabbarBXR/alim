import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/audio.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'hadith.dart';
import 'mushaf.dart';
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
  final ItemScrollController _scroll = ItemScrollController();
  bool _translation = true;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _translation = ref.read(profileProvider).translationOn;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final view = ref.watch(surahViewProvider(widget.surah));
    final audio = ref.watch(audioProvider);
    final playingHere = audio.surah == widget.surah ? audio.ayah : null;
    final audioBusy = playingHere != null && (audio.playing || audio.loading);
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
    final read = ref.watch(readSetProvider).valueOrNull ?? const <int>{};
    final surah = view.valueOrNull?.surah;
    final lastRead = ref.watch(lastReadProvider).valueOrNull;
    final bookmarkedAyat =
        ref
            .watch(bookmarksProvider('ayah'))
            .valueOrNull
            ?.map((b) => b.ref)
            .toSet() ??
        const <int>{};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(surah?.name ?? ''),
            if (surah != null)
              Text(
                '${surah.meaning} · ${surah.revelation}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AlimColors.mutedOf(context),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: audioBusy ? 'Pause' : 'Listen',
            icon: Icon(
              audioBusy
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
            onPressed:
                view.valueOrNull == null
                    ? null
                    : () {
                      final loaded = view.valueOrNull!;
                      ref
                          .read(audioProvider.notifier)
                          .toggleSurah(
                            surahNumber: loaded.surah.number,
                            surahName: loaded.surah.name,
                            ayat: loaded.ayat,
                            reciter: ref.read(activeReciterProvider),
                            startAyah: widget.focusAyah,
                          );
                    },
          ),
          IconButton(
            tooltip: 'Mushaf page',
            icon: const Icon(Icons.import_contacts_outlined),
            onPressed:
                view.valueOrNull == null
                    ? null
                    : () {
                      final target =
                          widget.focusAyah ??
                          view.valueOrNull!.ayat.first.number;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MushafScreen(initialAyah: target),
                        ),
                      );
                    },
          ),
          IconButton(
            tooltip: _translation ? 'Hide translation' : 'Show translation',
            icon: Icon(
              _translation ? Icons.translate : Icons.translate_outlined,
            ),
            onPressed: () => setState(() => _translation = !_translation),
          ),
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                ),
          ),
        ],
      ),
      body: switch (view) {
        AsyncData(:final value) => _reader(
          context,
          value,
          profile.arabicScale,
          read,
          lastRead,
          bookmarkedAyat,
          playingHere,
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar:
          playingHere == null || view.valueOrNull == null
              ? null
              : _AudioBar(
                audio: audio,
                label: _audioLabel(view.valueOrNull!, playingHere),
                onPrevious: () => ref.read(audioProvider.notifier).previous(),
                onNext: () => ref.read(audioProvider.notifier).next(),
                onToggle: () => ref.read(audioProvider.notifier).toggle(),
                onClose: () => ref.read(audioProvider.notifier).stop(),
              ),
    );
  }

  String _audioLabel(SurahView view, int number) {
    if (number < view.surah.firstAyah ||
        number >= view.surah.firstAyah + view.surah.ayat) {
      return view.surah.name;
    }
    final local = number - view.surah.firstAyah + 1;
    return '${view.surah.name} $local';
  }

  Widget _reader(
    BuildContext context,
    SurahView view,
    double scale,
    Set<int> read,
    int? lastRead,
    Set<int> bookmarkedAyat,
    int? playingAyah,
  ) {
    final focusIndex =
        widget.focusAyah == null
            ? null
            : view.ayat.indexWhere((a) => a.number == widget.focusAyah);

    final showBismillah = view.surah.number != 1 && view.surah.number != 9;
    final headerCount = showBismillah ? 2 : 1;

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
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        AlimSpace.sm,
        AlimSpace.lg,
        AlimSpace.xxl * 2,
      ),
      itemCount: view.ayat.length + headerCount,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AlimSpace.sm),
            child: _surahHeader(context, view.surah),
          );
        }
        if (showBismillah && i == 1) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AlimSpace.sm),
            child: BismillahBand(),
          );
        }
        final ayah = view.ayat[i - headerCount];
        final isRead = read.contains(ayah.number);
        final focused = widget.focusAyah == ayah.number;
        return _AyahTile(
          key: ValueKey(ayah.number),
          ayah: ayah,
          surahName: view.surah.name,
          scale: scale,
          translation: _translation,
          isRead: isRead,
          isLastRead: lastRead == ayah.number,
          bookmarked: bookmarkedAyat.contains(ayah.number),
          focused: focused,
          playing: playingAyah == ayah.number,
          onPlay:
              () => ref
                  .read(audioProvider.notifier)
                  .play(
                    surahNumber: view.surah.number,
                    surahName: view.surah.name,
                    ayat: view.ayat,
                    reciter: ref.read(activeReciterProvider),
                    startAyah: ayah.number,
                  ),
          onTap: () async {
            await ref.read(actionsProvider).markAyahRead(ayah.number);
            if (!context.mounted) return;
            showAyahSheet(context, ref, ayah, view.surah.name);
          },
        );
      },
    );
  }

  Widget _surahHeader(BuildContext context, Surah surah) {
    return AlimCard(
      padding: const EdgeInsets.all(AlimSpace.md),
      child: Row(
        children: [
          StarNumber(number: surah.number, size: 48, filled: true),
          const SizedBox(width: AlimSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surah.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  '${surah.meaning} · ${surah.ayat} ayat · ${surah.revelation}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            surah.nameAr,
            style: const TextStyle(
              fontFamily: arabicFamily,
              fontSize: 24,
              color: AlimColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahTile extends StatelessWidget {
  const _AyahTile({
    super.key,
    required this.ayah,
    required this.surahName,
    required this.scale,
    required this.translation,
    required this.isRead,
    required this.isLastRead,
    required this.bookmarked,
    required this.focused,
    required this.playing,
    required this.onPlay,
    required this.onTap,
  });

  final Ayah ayah;
  final String surahName;
  final double scale;
  final bool translation;
  final bool isRead;
  final bool isLastRead;
  final bool bookmarked;
  final bool focused;
  final bool playing;
  final VoidCallback onPlay;
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AlimSpace.sm),
      child: AlimCard(
        color: highlight,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.md,
          AlimSpace.md,
          AlimSpace.md,
          AlimSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    ayah.textAr,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: quranFamily,
                      fontSize: 24 * scale,
                      height: 1.9,
                    ),
                  ),
                ),
                const SizedBox(width: AlimSpace.xs),
                IconButton(
                  tooltip: playing ? 'Playing' : 'Play this ayah',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 22,
                    color:
                        playing
                            ? AlimColors.gold
                            : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.75),
                  ),
                  onPressed: onPlay,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child:
                      isRead
                          ? Icon(
                            Icons.check_circle,
                            size: 21,
                            color: Theme.of(context).colorScheme.primary,
                          )
                          : Icon(
                            Icons.circle_outlined,
                            size: 21,
                            color: AlimColors.mutedOf(
                              context,
                            ).withValues(alpha: 0.55),
                          ),
                ),
              ],
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
                  const Icon(Icons.bookmark, size: 14, color: AlimColors.gold),
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
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({
    required this.audio,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToggle,
    required this.onClose,
  });

  final AudioView audio;
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final subtitle =
        audio.failed
            ? 'Could not play this ayah. Try the next one.'
            : audio.loading
            ? 'Loading...'
            : '$label, ${audio.reciterName ?? ''}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xF215211D) : const Color(0xF7FFFDF8),
        border: Border(
          top: BorderSide(color: AlimColors.gold.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AlimSpace.xs, 0, AlimSpace.xs, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous ayah',
                icon: const Icon(Icons.skip_previous),
                onPressed: onPrevious,
              ),
              IconButton(
                tooltip: audio.playing ? 'Pause' : 'Play',
                iconSize: 38,
                color: AlimColors.gold,
                icon: Icon(
                  audio.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                onPressed: onToggle,
              ),
              IconButton(
                tooltip: 'Next ayah',
                icon: const Icon(Icons.skip_next),
                onPressed: onNext,
              ),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Stop',
                icon: const Icon(Icons.close),
                onPressed: onClose,
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
        ref.watch(readSetProvider).valueOrNull?.contains(ayah.number) ?? false;
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
