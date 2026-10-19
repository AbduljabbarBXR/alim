import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quran_reader.dart';

class DuaEntry {
  const DuaEntry({
    required this.title,
    required this.surah,
    required this.ayah,
    required this.who,
    required this.story,
  });

  final String title;
  final int surah;
  final int ayah;
  final String who;
  final String story;
}

const duas = <DuaEntry>[
  DuaEntry(
    title: 'Words after the fall',
    surah: 7,
    ayah: 23,
    who: 'Adam and Hawwa',
    story:
        'They turned back to Allah after eating from the tree. He taught them '
        'the words of repentance and accepted them.',
  ),
  DuaEntry(
    title: 'From the belly of the whale',
    surah: 21,
    ayah: 87,
    who: 'Yunus',
    story:
        'In the darkness of the whale he called with these words. Allah '
        'answered and saved him, and then guided the people of Nineveh.',
  ),
  DuaEntry(
    title: 'When illness would not leave',
    surah: 21,
    ayah: 83,
    who: 'Ayyub',
    story:
        'He lost his health, his family and his wealth, and still he called '
        'Allah the Most Merciful. Allah removed the harm and restored him.',
  ),
  DuaEntry(
    title: 'A child in old age',
    surah: 3,
    ayah: 38,
    who: 'Zakariya',
    story:
        'Standing in the prayer niche, he asked for a good offspring. Allah '
        'gave him Yahya, though he was old and his wife could not bear.',
  ),
  DuaEntry(
    title: 'A tongue for the truth',
    surah: 20,
    ayah: 25,
    who: 'Musa',
    story:
        'Sent to Pharaoh, he asked for an open chest and an easy task. Allah '
        'answered and made Harun his helper.',
  ),
  DuaEntry(
    title: 'Shelter in the cave',
    surah: 18,
    ayah: 10,
    who: 'The young men of the cave',
    story:
        'They fled their people for their faith and asked for mercy and '
        'guidance. Allah sheltered them and kept them safe for years.',
  ),
  DuaEntry(
    title: 'While raising the House',
    surah: 2,
    ayah: 127,
    who: 'Ibrahim and Isma\'il',
    story:
        'They built the Kaaba with their hands and asked Allah to accept it. '
        'He accepted their work and raised a prophet from their line.',
  ),
  DuaEntry(
    title: 'Gratitude for a small thing',
    surah: 27,
    ayah: 19,
    who: 'Sulayman',
    story:
        'He smiled at the speech of an ant and asked to be grateful for what '
        'he had been given. Allah gave him a kingdom unlike any after him.',
  ),
  DuaEntry(
    title: 'Good in both worlds',
    surah: 2,
    ayah: 201,
    who: 'The believers',
    story:
        'A short and balanced prayer, asking for good in this life and the '
        'next, and protection from the Fire.',
  ),
  DuaEntry(
    title: 'When the whisper comes',
    surah: 23,
    ayah: 97,
    who: 'The believers',
    story:
        'A shelter for the heart when the devils stir doubt. It is followed '
        'by the same refuge in the next ayah.',
  ),
  DuaEntry(
    title: 'A request for knowledge',
    surah: 20,
    ayah: 114,
    who: 'The Prophet, peace be upon him',
    story:
        'Allah taught His Prophet this single request to keep repeating: '
        'more knowledge, taken with humility.',
  ),
  DuaEntry(
    title: 'Comfort at home',
    surah: 25,
    ayah: 74,
    who: 'The servants of the Most Merciful',
    story:
        'They ask for spouses and children who are a comfort, and for a life '
        'that leads others toward what is good.',
  ),
];

class DuasScreen extends ConsumerWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayProvider).difference(DateTime(2026)).inDays;
    final pick = duas[day % duas.length];
    return Scaffold(
      appBar: AppBar(title: const Text('Duas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          0,
          AlimSpace.lg,
          AlimSpace.xxl,
        ),
        children: [
          Text(
            'Duas from the Qur\'an, with the one who said them and what '
            'happened next. The Arabic and the English are read from the '
            'same book you carry.',
            style: TextStyle(
              color: AlimColors.mutedOf(context),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          const SectionHeader('Dua of the day'),
          _DuaCard(entry: pick, featured: true),
          const SectionHeader('In the Qur\'an'),
          for (final entry in duas) _DuaCard(entry: entry),
        ],
      ),
    );
  }
}

class _DuaCard extends ConsumerWidget {
  const _DuaCard({required this.entry, this.featured = false});

  final DuaEntry entry;
  final bool featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayah = ref.watch(ayahAtProvider((entry.surah, entry.ayah)));
    final book = ref.watch(surahViewProvider(entry.surah)).valueOrNull;
    final source = 'Qur\'an ${entry.surah}:${entry.ayah}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AlimSpace.sm),
      child: AlimCard(
        color:
            featured
                ? AlimColors.goldSoft.withValues(
                  alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.08
                          : 1,
                )
                : null,
        border: featured ? AlimColors.gold.withValues(alpha: 0.35) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                const SizedBox(width: AlimSpace.xs),
                AlimPill(label: source, color: AlimColors.gold),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              entry.who,
              style: TextStyle(
                color: AlimColors.mutedOf(context),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: AlimSpace.sm),
            switch (ayah) {
              AsyncData(:final value) => Text(
                value.textAr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: quranFamily,
                  fontSize: 23,
                  height: 1.9,
                ),
              ),
              AsyncError() => Text(
                'The ayah could not be read.',
                style: TextStyle(color: AlimColors.mutedOf(context)),
              ),
              _ => const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            },
            const SizedBox(height: AlimSpace.xs),
            switch (ayah) {
              AsyncData(:final value) => Text(
                value.textEn,
                style: const TextStyle(height: 1.6, fontSize: 14),
              ),
              _ => const SizedBox.shrink(),
            },
            const SizedBox(height: AlimSpace.sm),
            Text(
              entry.story,
              style: TextStyle(
                color: AlimColors.mutedOf(context),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AlimSpace.xs),
            Row(
              children: [
                TextButton.icon(
                  onPressed:
                      book == null
                          ? null
                          : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => QuranReaderScreen(
                                    surah: entry.surah,
                                    focusAyah:
                                        book.surah.firstAyah + entry.ayah - 1,
                                  ),
                            ),
                          ),
                  icon: const Icon(Icons.menu_book_outlined, size: 17),
                  label: const Text('Read in the Qur\'an'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Share this dua',
                  icon: const Icon(Icons.ios_share, size: 19),
                  onPressed:
                      ayah.valueOrNull == null
                          ? null
                          : () => Share.share(
                            '${ayah.value!.textAr}\n\n'
                            '${ayah.value!.textEn}\n'
                            '$source\n\nAlim',
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
