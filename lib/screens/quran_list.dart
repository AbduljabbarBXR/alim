import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quran_reader.dart';

class QuranListScreen extends ConsumerStatefulWidget {
  const QuranListScreen({super.key});

  @override
  ConsumerState<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends ConsumerState<QuranListScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final surahs = ref.watch(surahsProvider);
    final results = ref.watch(searchProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Qur\'an'),
        actions: [
          IconButton(
            tooltip: 'Bookmarks',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              0,
              AlimSpace.lg,
              AlimSpace.sm,
            ),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search the Qur\'an — Arabic or English',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: query.length >= 2
                ? _searchResults(results.valueOrNull ?? const [])
                : _surahList(surahs.valueOrNull ?? const []),
          ),
        ],
      ),
    );
  }

  Widget _surahList(List<Surah> surahs) {
    if (surahs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        0,
        AlimSpace.lg,
        AlimSpace.xxl,
      ),
      itemCount: surahs.length,
      itemBuilder: (context, i) {
        final s = surahs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AlimSpace.sm),
          child: AlimCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AlimSpace.md,
              vertical: AlimSpace.sm,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuranReaderScreen(surah: s.number),
              ),
            ),
            child: Row(
              children: [
                StarNumber(number: s.number, size: 42),
                const SizedBox(width: AlimSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          AlimPill(
                            label: '${s.ayat} ayat',
                            color: AlimColors.mutedOf(context),
                          ),
                          const SizedBox(width: 6),
                          AlimPill(
                            label: s.revelation,
                            color: s.revelation == 'Mecca'
                                ? AlimColors.gold
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AlimSpace.sm),
                Text(
                  s.nameAr,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: arabicFamily,
                    fontSize: 21,
                    color: AlimColors.gold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchResults(List<Ayah> results) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AlimSpace.lg),
        child: EmptyNote(
          text: 'Nothing found. Try another word — Alim looks past the '
              'diacritics in Arabic.',
          icon: Icons.search_off,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        0,
        AlimSpace.lg,
        AlimSpace.xxl,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final a = results[i];
        final surah = ref.watch(surahOfAyahProvider(a.number)).valueOrNull;
        return Padding(
          padding: const EdgeInsets.only(bottom: AlimSpace.sm),
          child: AlimCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuranReaderScreen(
                  surah: a.surah,
                  focusAyah: a.number,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  a.textAr,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: quranFamily,
                    fontSize: 19,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: AlimSpace.xs),
                Text(
                  a.textEn,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.5, fontSize: 13.5),
                ),
                const SizedBox(height: AlimSpace.xs),
                Text(
                  '${surah?.name ?? ''} ${a.surah}:${a.ayah}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
