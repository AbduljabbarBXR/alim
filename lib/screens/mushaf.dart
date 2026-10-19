import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The mushaf as pages, the way it sits on the shelf: one page on screen,
/// surah bands where a surah opens, ayah markers in Arabic numerals.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, this.initialAyah});

  /// Global ayah number to open at.
  final int? initialAyah;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  PageController? _controller;
  int _page = 1;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    var page = 1;
    final target = widget.initialAyah;
    if (target != null) {
      page = await ref.read(storeProvider).pageOfAyah(target);
    }
    if (!mounted) return;
    setState(() {
      _page = page;
      _controller = PageController(initialPage: page - 1);
      _ready = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = ref.watch(pageCountProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageCount.valueOrNull == null
              ? 'Mushaf'
              : 'Page $_page of ${pageCount.valueOrNull}',
        ),
      ),
      body: pageCount.when(
        data: (count) => !_ready
            ? const Center(child: CircularProgressIndicator())
            : PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (i) => setState(() => _page = i + 1),
                itemBuilder: (context, i) => _MushafPage(
                  page: i + 1,
                  highlight: widget.initialAyah,
                ),
              ),
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MushafPage extends ConsumerWidget {
  const _MushafPage({required this.page, this.highlight});

  final int page;
  final int? highlight;

  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

  static String _digits(int n) =>
      '$n'.split('').map((d) => _arabicDigits[int.parse(d)]).join();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayat = ref.watch(pageAyatProvider(page));
    final surahs = ref.watch(surahsProvider).valueOrNull ?? const <Surah>[];
    Surah? surahOf(int number) =>
        surahs.where((s) => s.number == number).firstOrNull;

    return ayat.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final children = <Widget>[];
        var runStart = 0;
        for (var i = 0; i <= list.length; i++) {
          final end =
              i == list.length || list[i].surah != list[runStart].surah;
          if (!end) continue;
          final run = list.sublist(runStart, i);
          final surah = surahOf(run.first.surah);
          if (runStart == 0) {
            children.add(_marginHeader(context, surah, run.first.juz));
          } else {
            children.add(_surahBand(context, surah));
            if (run.first.surah != 1 && run.first.surah != 9) {
              children.add(const Padding(
                padding: EdgeInsets.only(top: AlimSpace.sm),
                child: BismillahBand(),
              ));
            }
          }
          children.add(Padding(
            padding: const EdgeInsets.only(top: AlimSpace.md),
            child: _text(context, run),
          ));
          runStart = i;
        }
        children.add(Padding(
          padding: const EdgeInsets.only(top: AlimSpace.lg),
          child: Text(
            'Page $page',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AlimColors.mutedOf(context), fontSize: 12),
          ),
        ));
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AlimSpace.lg,
            AlimSpace.xs,
            AlimSpace.lg,
            AlimSpace.xxl,
          ),
          children: children,
        );
      },
      error: (e, _) => Center(child: Text('$e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _marginHeader(BuildContext context, Surah? surah, int juz) {
    final style = TextStyle(
      color: AlimColors.mutedOf(context),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        Text('Juz $juz', style: style),
        const Spacer(),
        Text(surah?.name ?? '', style: style),
        if (surah != null) ...[
          const SizedBox(width: 6),
          Text(
            surah.nameAr,
            style: const TextStyle(
              fontFamily: arabicFamily,
              fontSize: 14,
              color: AlimColors.gold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _surahBand(BuildContext context, Surah? surah) {
    if (surah == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AlimSpace.sm),
      child: AlimCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AlimSpace.md,
          vertical: AlimSpace.sm,
        ),
        child: Row(
          children: [
            StarNumber(number: surah.number, size: 36),
            const SizedBox(width: AlimSpace.md),
            Expanded(
              child: Text(
                '${surah.name} · ${surah.meaning}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
            Text(
              surah.nameAr,
              style: const TextStyle(
                fontFamily: arabicFamily,
                fontSize: 18,
                color: AlimColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(BuildContext context, List<Ayah> run) {
    final base = TextStyle(
      fontFamily: quranFamily,
      fontSize: 24,
      height: 2.1,
      color: AlimColors.inkOf(context),
    );
    final mark = TextStyle(
      fontFamily: arabicFamily,
      fontSize: 19,
      height: 2.1,
      color: AlimColors.gold,
    );
    final spans = <TextSpan>[];
    for (final a in run) {
      spans.add(TextSpan(
        text: '${a.textAr} ',
        style: a.number == highlight
            ? base.copyWith(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.13),
              )
            : base,
      ));
      spans.add(TextSpan(text: '۝${_digits(a.ayah)} ', style: mark));
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
    );
  }
}
