import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HadithHomeScreen extends ConsumerWidget {
  const HadithHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(hadithCollectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hadith'),
        actions: const [_HadithSearchAction()],
      ),
      body: switch (collections) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            0,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          children: [
            AlimCard(
              color: AlimColors.leafSoft.withValues(
                alpha:
                    Theme.of(context).brightness == Brightness.dark ? 0.08 : 1,
              ),
              border: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.25),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AlimSpace.sm),
                  const Expanded(
                    child: Text(
                      'Only the authentic. The two Sahihs, Imam an-Nawawi\'s '
                      'forty, and the hadith Qudsi, with their chains of '
                      'trust intact.',
                      style: TextStyle(height: 1.5, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            for (final c in value) ...[
              const SizedBox(height: AlimSpace.sm),
              AlimCard(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HadithBookScreen(collection: c),
                      ),
                    ),
                child: Row(
                  children: [
                    StarNumber(number: value.indexOf(c) + 1, size: 44),
                    const SizedBox(width: AlimSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            c.blurb,
                            style: TextStyle(
                              color: AlimColors.mutedOf(context),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AlimPill(
                            label: '${c.count} hadith',
                            color: AlimColors.gold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AlimSpace.sm),
                    Text(
                      c.arabicName,
                      style: const TextStyle(
                        fontFamily: arabicFamily,
                        fontSize: 19,
                        color: AlimColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class HadithBookScreen extends ConsumerWidget {
  const HadithBookScreen({super.key, required this.collection});

  final HadithCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(hadithBooksProvider(collection.id));
    final loaded = books.valueOrNull;
    // Collections like the Forty of an-Nawawi and the Hadith Qudsi carry a
    // single body of text; going straight to it spares a pointless level.
    if (loaded != null && loaded.length == 1) {
      return HadithListScreen(
        collection: collection,
        book: loaded.single,
        showBook: false,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: const [_HadithSearchAction()],
      ),
      body: switch (books) {
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            AlimSpace.xs,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AlimSpace.xs),
          itemBuilder: (context, i) {
            final b = value[i];
            return AlimCard(
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              HadithListScreen(collection: collection, book: b),
                    ),
                  ),
              padding: const EdgeInsets.symmetric(
                horizontal: AlimSpace.md,
                vertical: AlimSpace.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${b.number}',
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Text(
                    '${b.count}',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18),
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

class HadithListScreen extends ConsumerWidget {
  const HadithListScreen({
    super.key,
    required this.collection,
    required this.book,
    this.showBook = true,
  });

  final HadithCollection collection;
  final HadithBook book;
  final bool showBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(hadithPageProvider((collection.id, book.number, 0)));
    final learnedToday =
        ref.watch(hadithReadSetProvider).valueOrNull ?? const <int>{};
    return Scaffold(
      appBar: AppBar(
        title:
            showBook
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: const TextStyle(fontSize: 16)),
                    Text(
                      '${collection.name} · book ${book.number}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AlimColors.mutedOf(context),
                      ),
                    ),
                  ],
                )
                : Text(collection.name),
        actions: const [_HadithSearchAction()],
      ),
      body: switch (page) {
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            AlimSpace.xs,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AlimSpace.sm),
          itemBuilder: (context, i) {
            final h = value[i];
            final learned = learnedToday.contains(h.id);
            return AlimCard(
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HadithDetailScreen(hadith: h),
                    ),
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.textEn,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.5, fontSize: 13.5),
                  ),
                  const SizedBox(height: AlimSpace.xs),
                  Row(
                    children: [
                      Text(
                        'No. ${h.numberInBook}',
                        style: TextStyle(
                          color: AlimColors.mutedOf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (learned)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
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

class HadithDetailScreen extends ConsumerWidget {
  const HadithDetailScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarked =
        ref.watch(bookmarkAtProvider(('hadith', hadith.id))).valueOrNull ??
        false;
    final learnedToday =
        ref.watch(hadithReadSetProvider).valueOrNull?.contains(hadith.id) ??
        false;
    final collection =
        ref
            .watch(hadithCollectionsProvider)
            .valueOrNull
            ?.where((c) => c.id == hadith.collection)
            .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(collection?.name ?? 'Hadith'),
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
                    .toggleBookmark(
                      'hadith',
                      hadith.id,
                      '${collection?.name ?? 'Hadith'} no. ${hadith.numberInBook}',
                    ),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed:
                () => Share.share(
                  '${hadith.textEn}\n\n${hadith.textAr}\n'
                  '${collection?.name ?? ''} no. ${hadith.numberInBook}',
                ),
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
          AlimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hadith.textEn,
                  style: const TextStyle(height: 1.7, fontSize: 16),
                ),
                const Divider(height: AlimSpace.xl),
                Text(
                  hadith.textAr,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: arabicFamily,
                    fontSize: 21,
                    height: 2,
                  ),
                ),
                const SizedBox(height: AlimSpace.sm),
                Row(
                  children: [
                    AlimPill(
                      label:
                          '${collection?.name ?? hadith.collection} '
                          'no. ${hadith.numberInBook}',
                      color: AlimColors.gold,
                      icon: Icons.verified_outlined,
                    ),
                    const Spacer(),
                    if (learnedToday)
                      AlimPill(
                        label: 'Learned today',
                        color: Theme.of(context).colorScheme.primary,
                        icon: Icons.check_circle_outline,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AlimSpace.md),
          FilledButton.icon(
            onPressed:
                learnedToday
                    ? null
                    : () async {
                      await ref.read(actionsProvider).learnedHadith(hadith.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '+20 XP · a hadith carried into today.',
                            ),
                          ),
                        );
                      }
                    },
            icon: const Icon(Icons.auto_stories),
            label: Text(
              learnedToday ? 'Counted for today' : 'Mark as learned today',
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithSearchAction extends StatelessWidget {
  const _HadithSearchAction();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Search the hadith',
      icon: const Icon(Icons.search),
      onPressed:
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HadithSearchScreen())),
    );
  }
}

/// Searches the chapter titles and the hadith text, in English or in Arabic.
/// Two letters are enough; the results narrow as the word grows.
class HadithSearchScreen extends ConsumerStatefulWidget {
  const HadithSearchScreen({super.key});

  @override
  ConsumerState<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends ConsumerState<HadithSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final active = query.length >= 2;
    final collections =
        ref.watch(hadithCollectionsProvider).valueOrNull ??
        const <HadithCollection>[];
    final byId = {for (final c in collections) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search hadith in English or Arabic',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body:
          !active
              ? const Padding(
                padding: EdgeInsets.all(AlimSpace.lg),
                child: EmptyNote(
                  text:
                      'Type at least two letters. Try prayer, patience, '
                      'or mercy.',
                  icon: Icons.search,
                ),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AlimSpace.lg,
                  0,
                  AlimSpace.lg,
                  AlimSpace.xxl,
                ),
                children: [..._books(query, byId), ..._hadiths(query, byId)],
              ),
    );
  }

  List<Widget> _books(String query, Map<String, HadithCollection> byId) {
    final books = ref.watch(hadithBookSearchProvider(query));
    return books.when(
      data: (value) {
        if (value.isEmpty) return const <Widget>[];
        return [
          const SectionHeader('Chapters'),
          for (final b in value)
            Padding(
              padding: const EdgeInsets.only(bottom: AlimSpace.xs),
              child: AlimCard(
                onTap: () {
                  final collection = byId[b.collection];
                  if (collection == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              HadithListScreen(collection: collection, book: b),
                    ),
                  );
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: AlimSpace.md,
                  vertical: AlimSpace.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${byId[b.collection]?.name ?? b.collection} · '
                            'book ${b.number}',
                            style: TextStyle(
                              color: AlimColors.mutedOf(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${b.count}',
                      style: TextStyle(
                        color: AlimColors.mutedOf(context),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
        ];
      },
      error: (error, _) => [Center(child: Text('$error'))],
      loading: () => const <Widget>[],
    );
  }

  List<Widget> _hadiths(String query, Map<String, HadithCollection> byId) {
    final results = ref.watch(hadithSearchProvider(query));
    final learnedToday =
        ref.watch(hadithReadSetProvider).valueOrNull ?? const <int>{};
    return results.when(
      data: (value) {
        if (value.isEmpty) {
          return const [
            SectionHeader('Hadith'),
            Padding(
              padding: EdgeInsets.all(AlimSpace.lg),
              child: EmptyNote(
                text: 'No hadith found for that word. Try a shorter one.',
                icon: Icons.search_off,
              ),
            ),
          ];
        }
        return [
          const SectionHeader('Hadith'),
          for (final h in value)
            Padding(
              padding: const EdgeInsets.only(bottom: AlimSpace.sm),
              child: AlimCard(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HadithDetailScreen(hadith: h),
                      ),
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.textEn,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.5, fontSize: 13.5),
                    ),
                    const SizedBox(height: AlimSpace.xs),
                    Row(
                      children: [
                        Text(
                          '${byId[h.collection]?.name ?? h.collection} '
                          'no. ${h.numberInBook}',
                          style: TextStyle(
                            color: AlimColors.mutedOf(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (learnedToday.contains(h.id))
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ];
      },
      error: (error, _) => [Center(child: Text('$error'))],
      loading:
          () => const [
            Padding(
              padding: EdgeInsets.all(AlimSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
    );
  }
}
