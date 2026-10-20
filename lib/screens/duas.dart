import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/duas.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'quran_reader.dart';

class DuasScreen extends ConsumerStatefulWidget {
  const DuasScreen({super.key});

  @override
  ConsumerState<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends ConsumerState<DuasScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DuaEntry> get _visible {
    final query = _query.trim().toLowerCase();
    return duas
        .where((entry) {
          if (_category != null && entry.category != _category) return false;
          if (query.isEmpty) return true;
          return entry.title.toLowerCase().contains(query) ||
              entry.who.toLowerCase().contains(query) ||
              entry.story.toLowerCase().contains(query) ||
              entry.category.toLowerCase().contains(query) ||
              entry.source.toLowerCase().contains(query) ||
              '${entry.surah}:${entry.ayah}'.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(todayProvider).difference(DateTime(2026)).inDays;
    final pick = duas[day.abs() % duas.length];
    final visible = _visible;
    final filtering = _query.trim().isNotEmpty || _category != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duas'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AlimSpace.lg),
              child: Text(
                '${duas.length} duas',
                style: TextStyle(
                  color: AlimColors.mutedOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AlimSpace.lg,
              AlimSpace.sm,
              AlimSpace.lg,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'A hundred turns to Allah from the Qur\'an, with the one who '
                  'said them and the story around them. The Arabic and the '
                  'English are read from the Book you carry.',
                  style: TextStyle(
                    color: AlimColors.mutedOf(context),
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: AlimSpace.md),
                if (!filtering) ...[
                  const SectionHeader('Dua of the day'),
                  _DuaCard(entry: pick, featured: true),
                  const SizedBox(height: AlimSpace.md),
                ],
                _SearchBox(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
                const SizedBox(height: AlimSpace.sm),
                _CategoryRail(
                  selected: _category,
                  onSelected:
                      (value) => setState(
                        () => _category = _category == value ? null : value,
                      ),
                ),
                SectionHeader(
                  filtering ? '${visible.length} found' : 'In the Qur\'an',
                  trailing: Text(
                    filtering ? 'of ${duas.length}' : '${visible.length} duas',
                    style: TextStyle(
                      color: AlimColors.mutedOf(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AlimSpace.xs),
              ]),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.all(AlimSpace.lg),
                child: EmptyNote(
                  text:
                      'No dua matches that search yet. Try a name, a theme or '
                      'a surah.',
                  icon: Icons.search_off_rounded,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AlimSpace.lg,
                0,
                AlimSpace.lg,
                AlimSpace.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _DuaCard(entry: visible[i]),
                  childCount: visible.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name, story or ayah',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon:
            controller.text.isEmpty
                ? null
                : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _chip(context, 'All', selected == null, () => onSelected(null)),
          for (final category in duaCategories)
            _chip(
              context,
              category,
              selected == category,
              () => onSelected(category),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active ? scheme.primary : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? scheme.primary : AlimColors.hairlineOf(context),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                color: active ? scheme.onPrimary : AlimColors.inkOf(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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
    final loaded = ayah.valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final ink = featured ? const Color(0xFFFBF6EA) : AlimColors.inkOf(context);
    final body =
        featured ? const Color(0xFFC7DCD2) : AlimColors.mutedOf(context);
    final accent = featured ? AlimColors.goldSoft : scheme.primary;
    final english = featured ? const Color(0xFFE3F1EB) : ink;
    final open =
        loaded == null
            ? null
            : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => QuranReaderScreen(
                      surah: loaded.surah,
                      focusAyah: loaded.number,
                    ),
              ),
            );
    final share =
        loaded == null
            ? null
            : () => Share.share(
              '${loaded.textAr}\n\n${loaded.textEn}\n${entry.source}\n\nAlim',
            );
    return Padding(
      padding: EdgeInsets.only(bottom: featured ? 0 : AlimSpace.sm),
      child: AlimCard(
        color: featured ? AlimColors.leafDeep : null,
        border:
            featured
                ? AlimColors.gold.withValues(alpha: 0.58)
                : AlimColors.hairlineOf(context),
        padding: EdgeInsets.all(featured ? 18 : AlimSpace.md),
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AlimPill(label: entry.category, color: accent),
                const Spacer(),
                AlimPill(label: entry.source, color: accent),
              ],
            ),
            const SizedBox(height: AlimSpace.sm),
            Text(
              entry.title,
              style: TextStyle(
                color: ink,
                fontSize: featured ? 21 : 15.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.who,
              style: TextStyle(
                color: body,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AlimSpace.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: featured ? 12 : 8,
              ),
              decoration: BoxDecoration(
                color:
                    featured
                        ? Colors.white.withValues(alpha: 0.045)
                        : AlimColors.gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AlimRadius.field),
                border: Border.all(
                  color:
                      featured
                          ? AlimColors.goldSoft.withValues(alpha: 0.18)
                          : AlimColors.gold.withValues(alpha: 0.18),
                ),
              ),
              child: switch (ayah) {
                AsyncData(:final value) => Text(
                  value.textAr,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: quranFamily,
                    fontSize: featured ? 24 : 21,
                    height: 1.9,
                    color: ink,
                  ),
                ),
                AsyncError() => Text(
                  'This ayah could not be read.',
                  style: TextStyle(color: body, fontSize: 12.5),
                ),
                _ => Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                ),
              },
            ),
            const SizedBox(height: AlimSpace.sm),
            switch (ayah) {
              AsyncData(:final value) => Text(
                value.textEn,
                style: TextStyle(color: english, fontSize: 14, height: 1.6),
              ),
              _ => const SizedBox.shrink(),
            },
            if (loaded != null) ...[
              const SizedBox(height: AlimSpace.sm),
              Text(
                entry.story,
                style: TextStyle(color: body, fontSize: 12.5, height: 1.55),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: open,
                    icon: const Icon(Icons.menu_book_outlined, size: 17),
                    label: const Text('Read in the Qur\'an'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Share this dua',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 18,
                      color: accent,
                    ),
                    onPressed: share,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
