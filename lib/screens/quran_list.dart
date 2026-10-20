import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services/audio_downloads.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/quran_ornaments.dart';
import '../widgets/surah_download.dart';
import 'mushaf.dart';
import 'quran_reader.dart';

/// The door to the Qur'an: continue where you stopped, walk the surahs, step
/// through the thirty juz, or return to a kept ayah. The section has its own
/// bronze and parchment room, separate from the rest of Alim.
class QuranListScreen extends ConsumerStatefulWidget {
  const QuranListScreen({super.key});

  @override
  ConsumerState<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends ConsumerState<QuranListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _query = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _tabs.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final p =
        brightness == Brightness.dark ? QuranPalette.dark : QuranPalette.light;
    final query = _query.text.trim();
    final surahs = ref.watch(surahsProvider);

    return Theme(
      data: buildQuranTheme(brightness),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title:
              _searching
                  ? TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: p.ink, fontSize: 16),
                    cursorColor: p.bronze,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Search in Arabic or English',
                      hintStyle: TextStyle(color: p.muted, fontSize: 15),
                    ),
                  )
                  : Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.bronzeTint,
                          border: Border.all(color: p.faintBronze),
                        ),
                        child: Text(
                          'ق',
                          style: TextStyle(
                            fontFamily: arabicFamily,
                            fontSize: 20,
                            height: 1,
                            color: p.bronze,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Read Qur\'an',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: arabicFamily,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
          actions:
              _searching
                  ? [
                    IconButton(
                      tooltip: 'Close search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _query.clear();
                        setState(() => _searching = false);
                      },
                    ),
                  ]
                  : [
                    IconButton(
                      tooltip: 'Search the Qur\'an',
                      icon: const Icon(Icons.search),
                      onPressed: () => setState(() => _searching = true),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'juz':
                            _tabs.animateTo(1);
                          case 'bookmarks':
                            _tabs.animateTo(2);
                          case 'mushaf':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MushafScreen(),
                              ),
                            );
                        }
                      },
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(value: 'juz', child: Text('By Juz')),
                            PopupMenuItem(
                              value: 'bookmarks',
                              child: Text('Bookmarks'),
                            ),
                            PopupMenuItem(
                              value: 'mushaf',
                              child: Text('Mushaf pages'),
                            ),
                          ],
                    ),
                  ],
          bottom:
              _searching
                  ? null
                  : PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        controller: _tabs,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 3,
                        labelPadding: EdgeInsets.zero,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Surah'),
                          Tab(text: 'Juz'),
                          Tab(text: 'Bookmarks'),
                        ],
                      ),
                    ),
                  ),
        ),
        body:
            _searching
                ? _SearchBody(query: query)
                : TabBarView(
                  controller: _tabs,
                  children: [
                    _SurahTab(surahs: surahs.valueOrNull ?? const []),
                    const _JuzTab(),
                    const _BookmarksTab(),
                  ],
                ),
      ),
    );
  }
}

class _SurahTab extends ConsumerWidget {
  const _SurahTab({required this.surahs});

  final List<Surah> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    if (surahs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AlimSpace.xxl),
      itemCount: surahs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ContinueCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${surahs.length} surahs',
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '6,236 ayat',
                      style: TextStyle(color: p.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Divider(color: p.hairlineSoft, height: 1),
            ],
          );
        }
        return _SurahRow(surah: surahs[index - 1]);
      },
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    final lastRead = ref.watch(lastReadProvider).valueOrNull;
    final surah =
        lastRead == null
            ? null
            : ref.watch(surahOfAyahProvider(lastRead)).valueOrNull;
    final ayah =
        lastRead == null ? null : ref.watch(ayahProvider(lastRead)).valueOrNull;
    final hasPlace = lastRead != null && surah != null && ayah != null;

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => QuranReaderScreen(
                surah: surah?.number ?? 1,
                focusAyah: lastRead,
              ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: open,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.hairline),
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                StarNumber(
                  number: surah?.number ?? 1,
                  size: 40,
                  color: p.bronze,
                  strokeWidth: 1.5,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPlace ? 'Continue reading' : 'Begin reading',
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPlace
                            ? '${surah.name} · ayah ${ayah.ayah}'
                            : 'Al-Fatihah, the opening',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  hasPlace
                      ? Icons.play_arrow_rounded
                      : Icons.menu_book_outlined,
                  color: p.bronze,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahRow extends ConsumerWidget {
  const _SurahRow({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    final reciter = ref.watch(activeReciterProvider);
    final downloads = ref.watch(audioDownloadsProvider);
    final manager = ref.watch(audioDownloadsProvider.notifier);
    final saved = manager.isSurahDownloaded(reciter.id, surah.number);
    final task = downloads['${reciter.id}/${surah.number}'];
    final busy = task?.busy ?? false;
    final failed = task?.phase == DownloadPhase.failed;
    final place = surah.revelation == 'Madina' ? 'Medinan' : 'Meccan';

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuranReaderScreen(surah: surah.number),
        ),
      );
    }

    Future<void> download() async {
      if (busy) return;
      if (saved) {
        await removeSurahDownload(context, ref, reciter: reciter, surah: surah);
        return;
      }
      await showSurahDownloadSheet(
        context,
        reciter: reciter,
        surah: surah.number,
        surahName: surah.name,
        ayatCount: surah.ayat,
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
            child: Row(
              children: [
                StarNumber(
                  number: surah.number,
                  size: 42,
                  color: p.bronze,
                  strokeWidth: 1.6,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surah.meaning} · $place · ${surah.ayat} ayat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    surah.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: arabicFamily,
                      fontSize: 22,
                      height: 1.2,
                      color: p.bronze,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      saved
                          ? 'Saved offline'
                          : busy
                          ? 'Saving'
                          : failed
                          ? 'Try the download again'
                          : 'Download this surah',
                  child: Material(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: download,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.hairline),
                        ),
                        child:
                            busy
                                ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.bronze,
                                  ),
                                )
                                : Icon(
                                  saved
                                      ? Icons.cloud_done_outlined
                                      : failed
                                      ? Icons.refresh_rounded
                                      : Icons.cloud_download_outlined,
                                  size: 19,
                                  color: saved ? p.accent : p.bronze,
                                ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, indent: 72, endIndent: 16, color: p.hairlineSoft),
      ],
    );
  }
}

class _JuzTab extends ConsumerWidget {
  const _JuzTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    final starts = ref.watch(juzStartsProvider);
    return switch (starts) {
      AsyncData(:final value) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, AlimSpace.xxl),
        children: [
          Text(
            'Thirty parts, one Book',
            style: TextStyle(
              color: p.ink,
              fontFamily: arabicFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Each juz opens at its first ayah in the mushaf.',
            style: TextStyle(color: p.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemCount: value.length,
            itemBuilder: (context, i) {
              return Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MushafScreen(initialAyah: value[i]),
                        ),
                      ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          quranDigits(i + 1),
                          style: TextStyle(
                            fontFamily: arabicFamily,
                            color: p.bronze,
                            fontSize: 25,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Juz ${i + 1}',
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ayah ${value[i]}',
                          style: TextStyle(color: p.muted, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    final bookmarks = ref.watch(bookmarksProvider(null));
    return switch (bookmarks) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarNumber(
                number: 8,
                size: 54,
                color: p.bronze,
                strokeWidth: 1.2,
              ),
              const SizedBox(height: 14),
              Text(
                'Nothing kept yet',
                style: TextStyle(
                  color: p.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bookmark an ayah, a hadith or a story and it waits here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, AlimSpace.xxl),
        itemCount: value.length,
        itemBuilder: (context, i) {
          final b = value[i];
          final icon = switch (b.kind) {
            'ayah' => Icons.menu_book_outlined,
            'hadith' => Icons.auto_stories_outlined,
            _ => Icons.local_library_outlined,
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openBookmark(context, ref, b),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.hairline),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: p.bronze),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          b.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove bookmark',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: p.muted,
                        ),
                        onPressed:
                            () => ref
                                .read(actionsProvider)
                                .toggleBookmark(b.kind, b.ref, b.label),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = QuranPalette.of(context);
    if (query.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 34, color: p.muted),
              const SizedBox(height: 10),
              Text(
                'Type at least two letters.',
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                'Arabic diacritics are looked past.',
                style: TextStyle(color: p.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      );
    }
    final results = ref.watch(searchProvider(query));
    return switch (results) {
      AsyncData(:final value) when value.isEmpty => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Nothing found. Try another word.',
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
        ),
      ),
      AsyncData(:final value) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, AlimSpace.xxl),
        itemCount: value.length,
        itemBuilder: (context, i) {
          final a = value[i];
          final surah = ref.watch(surahOfAyahProvider(a.number)).valueOrNull;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => QuranReaderScreen(
                              surah: a.surah,
                              focusAyah: a.number,
                            ),
                      ),
                    ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.hairline),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        a.textAr,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: quranFamily,
                          fontSize: 20,
                          height: 1.8,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.textEn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.translation,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${surah?.name ?? ''} ${a.surah}:${a.ayah}',
                        style: TextStyle(
                          color: p.latin,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
