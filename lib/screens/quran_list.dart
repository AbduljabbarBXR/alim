import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'mushaf.dart';
import 'quran_reader.dart';

/// The door to the Qur'an: pick up where you left off, step through the juz,
/// or walk the surahs one by one.
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
      appBar: AppBar(title: const Text('The Qur\'an')),
      body: query.length >= 2
          ? _searchResults(results.valueOrNull ?? const [])
          : _hub(surahs.valueOrNull ?? const []),
    );
  }

  Widget _hub(List<Surah> surahs) {
    if (surahs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        0,
        AlimSpace.lg,
        AlimSpace.xxl,
      ),
      children: [
        _continueCard(),
        const SizedBox(height: AlimSpace.sm),
        Row(
          children: [
            Expanded(
              child: _featureTile(
                context,
                icon: Icons.grid_view_rounded,
                label: 'By Juz',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JuzListScreen()),
                ),
              ),
            ),
            const SizedBox(width: AlimSpace.sm),
            Expanded(
              child: _featureTile(
                context,
                icon: Icons.bookmarks_outlined,
                label: 'Bookmarks',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                ),
              ),
            ),
          ],
        ),
        const SectionHeader('Read by surah'),
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search the Qur\'an in Arabic or English',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.text.isEmpty
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
        const SizedBox(height: AlimSpace.sm),
        for (final s in surahs) _surahCard(s),
      ],
    );
  }

  Widget _continueCard() {
    final lastRead = ref.watch(lastReadProvider).valueOrNull;
    final surah = lastRead == null
        ? null
        : ref.watch(surahOfAyahProvider(lastRead)).valueOrNull;
    final ayah = lastRead == null
        ? null
        : ref.watch(ayahProvider(lastRead)).valueOrNull;

    void open() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuranReaderScreen(
            surah: surah?.number ?? 1,
            focusAyah: lastRead,
          ),
        ),
      );
    }

    return AlimCard(
      color: AlimColors.goldSoft.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1,
      ),
      border: AlimColors.gold.withValues(alpha: 0.35),
      onTap: open,
      child: Row(
        children: [
          StarNumber(
            number: surah?.number ?? 1,
            size: 44,
            filled: true,
          ),
          const SizedBox(width: AlimSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastRead == null ? 'Begin reading' : 'Continue reading',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lastRead == null || surah == null || ayah == null
                      ? 'From Al-Fatihah, the opening'
                      : '${surah.name} ${ayah.surah}:${ayah.ayah}',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: AlimColors.gold, size: 28),
        ],
      ),
    );
  }

  Widget _featureTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AlimCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AlimSpace.md,
        vertical: AlimSpace.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AlimSpace.sm),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _surahCard(Surah s) {
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
  }

  Widget _searchResults(List<Ayah> results) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AlimSpace.lg),
        child: EmptyNote(
          text: 'Nothing found. Try another word. Alim looks past the '
              'diacritics in Arabic.',
          icon: Icons.search_off,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AlimSpace.lg,
        AlimSpace.xs,
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

/// The thirty juz, each opening the mushaf at its first page.
class JuzListScreen extends ConsumerWidget {
  const JuzListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starts = ref.watch(juzStartsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('By Juz')),
      body: switch (starts) {
        AsyncData(:final value) => GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              AlimSpace.sm,
              AlimSpace.lg,
              AlimSpace.xxl,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AlimSpace.sm,
              crossAxisSpacing: AlimSpace.sm,
              childAspectRatio: 1.5,
            ),
            itemCount: value.length,
            itemBuilder: (context, i) {
              return AlimCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MushafScreen(initialAyah: value[i]),
                  ),
                ),
                padding: const EdgeInsets.all(AlimSpace.sm),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Juz ${i + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'from ayah ${value[i]}',
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
