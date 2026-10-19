import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'hadith.dart';
import 'quran_reader.dart';

class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final stories = ref.watch(storiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stories')),
      body: switch (stories) {
        AsyncData(:final value) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AlimSpace.lg),
              child: Row(
                children: [
                  for (final f in const [
                    'All',
                    'Prophets',
                    'Companions',
                    'Chosen',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AlimSpace.xs),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AlimSpace.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AlimSpace.lg,
                  0,
                  AlimSpace.lg,
                  AlimSpace.xxl,
                ),
                children: [
                  for (final s in value.where(
                    (s) => _filter == 'All' || s.category == _filter,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AlimSpace.sm),
                      child: _StoryCard(story: s),
                    ),
                ],
              ),
            ),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StoryCard extends ConsumerWidget {
  const _StoryCard({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(storyReadProvider(story.id)).valueOrNull ?? false;
    return AlimCard(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)),
          ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  story.lesson,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AlimPill(label: story.category, color: AlimColors.gold),
                    const SizedBox(width: 6),
                    AlimPill(
                      label: '${story.minutes} min',
                      color: AlimColors.mutedOf(context),
                      icon: Icons.schedule,
                    ),
                    if (read) ...[
                      const SizedBox(width: 6),
                      AlimPill(
                        label: 'Read',
                        color: Theme.of(context).colorScheme.primary,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            read ? Icons.check_circle : Icons.chevron_right,
            color:
                read
                    ? Theme.of(context).colorScheme.primary
                    : AlimColors.mutedOf(context),
            size: read ? 22 : 20,
          ),
        ],
      ),
    );
  }
}

class StoryDetailScreen extends ConsumerWidget {
  const StoryDetailScreen({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(storyReadProvider(story.id)).valueOrNull ?? false;
    final ayah =
        story.ayahNumber == null
            ? null
            : ref.watch(ayahProvider(story.ayahNumber!)).valueOrNull;
    final surah =
        ref.watch(surahOfAyahProvider(story.ayahNumber ?? 1)).valueOrNull;
    final bookmarked =
        ref.watch(bookmarkAtProvider(('story', story.id))).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(story.category),
        actions: [
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(
              bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: bookmarked ? AlimColors.gold : null,
            ),
            onPressed:
                () => ref
                    .read(actionsProvider)
                    .toggleBookmark('story', story.id, story.title),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          AlimSpace.xs,
          AlimSpace.lg,
          AlimSpace.xxl,
        ),
        children: [
          StarLattice(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AlimSpace.xs),
                Row(
                  children: [
                    AlimPill(label: story.category, color: AlimColors.gold),
                    const SizedBox(width: 6),
                    AlimPill(
                      label: '${story.minutes} min read',
                      color: AlimColors.mutedOf(context),
                      icon: Icons.schedule,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          AlimCard(
            padding: const EdgeInsets.all(AlimSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in story.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AlimSpace.md),
                    child: Text(
                      p,
                      style: const TextStyle(fontSize: 15.5, height: 1.75),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          AlimCard(
            color: AlimColors.leafSoft.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1,
            ),
            border: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AlimSpace.xs),
                    const Text(
                      'What it teaches',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AlimSpace.xs),
                Text(
                  story.lesson,
                  style: const TextStyle(height: 1.55, fontSize: 14),
                ),
              ],
            ),
          ),
          if (ayah != null) ...[
            const SectionHeader('In the Qur\'an'),
            AlimCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ayah.textAr,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: quranFamily,
                      fontSize: 22,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: AlimSpace.xs),
                  Text(
                    ayah.textEn,
                    style: const TextStyle(height: 1.6, fontSize: 13.5),
                  ),
                  const SizedBox(height: AlimSpace.xs),
                  Text(
                    '${surah?.name ?? ''} ${ayah.surah}:${ayah.ayah}',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AlimSpace.xs),
                  OutlinedButton.icon(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => QuranReaderScreen(
                                  surah: ayah.surah,
                                  focusAyah: ayah.number,
                                ),
                          ),
                        ),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Read it in context'),
                  ),
                ],
              ),
            ),
          ],
          if (story.hadithId != null) ...[
            const SectionHeader('In the Sunnah'),
            _HadithSourceCard(
              hadithId: story.hadithId!,
              reference: story.hadithRef,
            ),
          ],
          const SizedBox(height: AlimSpace.md),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(actionsProvider).readStory(story.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      read
                          ? 'Read again. The lesson deepens.'
                          : '+20 XP · story finished.',
                    ),
                  ),
                );
              }
            },
            icon: Icon(read ? Icons.replay : Icons.check),
            label: Text(read ? 'Read again' : 'Finished reading · +20 XP'),
          ),
        ],
      ),
    );
  }
}

/// The hadith that carries the story, with the collection reference the
/// database resolved for it.
class _HadithSourceCard extends ConsumerWidget {
  const _HadithSourceCard({required this.hadithId, this.reference});

  final int hadithId;
  final String? reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadith = ref.watch(hadithByIdProvider(hadithId)).valueOrNull;
    if (hadith == null) return const SizedBox.shrink();
    return AlimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reference != null)
            Align(
              alignment: Alignment.centerLeft,
              child: AlimPill(
                label: reference!,
                color: AlimColors.gold,
                icon: Icons.verified_outlined,
              ),
            ),
          const SizedBox(height: AlimSpace.sm),
          Text(
            hadith.textEn,
            style: const TextStyle(height: 1.65, fontSize: 14),
          ),
          const SizedBox(height: AlimSpace.sm),
          Text(
            hadith.textAr,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: arabicFamily,
              fontSize: 20,
              height: 2,
            ),
          ),
          const SizedBox(height: AlimSpace.xs),
          OutlinedButton.icon(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HadithDetailScreen(hadith: hadith),
                  ),
                ),
            icon: const Icon(Icons.auto_stories_outlined, size: 18),
            label: const Text('Open the hadith'),
          ),
        ],
      ),
    );
  }
}
