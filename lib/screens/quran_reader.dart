import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'hadith.dart';
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
  ScrollController? _controller;
  bool _translation = true;

  @override
  void initState() {
    super.initState();
    _translation = ref.read(profileProvider).translationOn;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Estimates where an ayah sits in the list. Ayat vary wildly in length, so
  /// the guess uses the Arabic text length at the reader's font scale.
  double _estimateOffset(List<Ayah> ayat, int index, double scale) {
    var y = 8.0;
    for (var i = 0; i < index; i++) {
      y += _estimateHeight(ayat[i], scale);
    }
    return y;
  }

  double _estimateHeight(Ayah a, double scale) {
    final arFont = 24 * scale;
    final arCharsPerLine = 380 / (arFont * 0.52);
    final arLines = (a.textAr.length / arCharsPerLine).ceil().clamp(1, 40);
    final arHeight = arLines * arFont * 1.9;
    final enLines = (a.textEn.length / 46).ceil().clamp(1, 30);
    final enHeight = _translation ? enLines * 14.5 * 1.6 + 8 : 0.0;
    return arHeight + enHeight + 78;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final view = ref.watch(surahViewProvider(widget.surah));
    final read = ref.watch(readSetProvider).valueOrNull ?? const <int>{};
    final surah = view.valueOrNull?.surah;
    final lastRead = ref.watch(lastReadProvider).valueOrNull;

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
            tooltip: _translation ? 'Hide translation' : 'Show translation',
            icon: Icon(
              _translation ? Icons.translate : Icons.translate_outlined,
            ),
            onPressed: () => setState(() => _translation = !_translation),
          ),
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
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
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _reader(
    BuildContext context,
    SurahView view,
    double scale,
    Set<int> read,
    int? lastRead,
  ) {
    final focusIndex = widget.focusAyah == null
        ? null
        : view.ayat.indexWhere((a) => a.number == widget.focusAyah);
    if (_controller == null) {
      final offset = focusIndex == null || focusIndex <= 0
          ? 0.0
          : _estimateOffset(view.ayat, focusIndex, scale);
      _controller = ScrollController(initialScrollOffset: offset);
      if (offset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Landed near ayah ${view.ayat[focusIndex!].ayah}. Tap ayat '
                  'to count them.',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    }

    final showBismillah = view.surah.number != 1 && view.surah.number != 9;
    final headerCount = showBismillah ? 2 : 1;

    return ListView.builder(
      controller: _controller,
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
          focused: focused,
          onRead: () async {
            final messenger = ScaffoldMessenger.of(context);
            final first =
                await ref.read(actionsProvider).markAyahRead(ayah.number);
            if (first) {
              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '${view.surah.name} ${ayah.ayah} counted today.',
                    ),
                    duration: const Duration(milliseconds: 900),
                  ),
                );
            }
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
    required this.focused,
    required this.onRead,
  });

  final Ayah ayah;
  final String surahName;
  final double scale;
  final bool translation;
  final bool isRead;
  final bool isLastRead;
  final bool focused;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final highlight = focused
        ? AlimColors.goldSoft.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.6,
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AlimSpace.sm),
      child: AlimCard(
        color: highlight,
        onTap: onRead,
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.md,
          AlimSpace.md,
          AlimSpace.sm,
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
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: isRead
                      ? Icon(
                          Icons.check_circle,
                          size: 21,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          size: 21,
                          color: AlimColors.mutedOf(context).withValues(
                            alpha: 0.55,
                          ),
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
                if (isLastRead) ...[
                  const SizedBox(width: AlimSpace.xs),
                  AlimPill(
                    label: 'Your place',
                    color: AlimColors.gold,
                  ),
                ],
                if (ayah.sajda) ...[
                  const SizedBox(width: AlimSpace.xs),
                  const AlimPill(
                    label: 'Sajda',
                    color: AlimColors.rose,
                  ),
                ],
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share',
                  icon: const Icon(Icons.ios_share, size: 17),
                  onPressed: () => Share.share(
                    '${ayah.textAr}\n\n${ayah.textEn}\n— Qur\'an ${ayah.surah}:${ayah.ayah}',
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
                    text: 'Nothing kept yet. Bookmark an ayah, a hadith or a '
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
                              onPressed: () => ref
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
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuranReaderScreen(
              surah: ayah.surah,
              focusAyah: ayah.number,
            ),
          ));
        }
      case 'hadith':
        final hadith = ref.read(hadithByIdProvider(b.ref)).valueOrNull;
        if (hadith != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithDetailScreen(hadith: hadith),
          ));
        }
      case 'story':
        final story = ref.read(storyProvider(b.ref)).valueOrNull;
        if (story != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StoryDetailScreen(story: story),
          ));
        }
    }
  }
}
