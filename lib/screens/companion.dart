import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/companion.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final _messages = <CompanionMessage>[
    const CompanionMessage(
      fromUser: false,
      text: 'Assalamu alaikum. Ask about an ayah, a hadith, or something you '
          'are carrying today. I am a study companion, not a scholar.',
    ),
  ];
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !companionEnabled) return;
    setState(() {
      _messages.add(CompanionMessage(fromUser: true, text: text));
      _input.clear();
      _sending = true;
    });
    try {
      final answer = await CompanionService(ref.read(storeProvider)).reply(
        history: _messages.sublist(0, _messages.length - 1),
        question: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(CompanionMessage(fromUser: false, text: answer));
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(const CompanionMessage(
          fromUser: false,
          text: 'I could not reach the server just now. Try again in a moment.',
        ));
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Companion')),
      body: !companionEnabled
          ? ListView(
              padding: const EdgeInsets.all(AlimSpace.lg),
              children: const [
                EmptyNote(
                  text: 'The study companion is switched off in this release. '
                      'It is written and waiting behind a single flag in '
                      'services/companion.dart.',
                  icon: Icons.auto_awesome_outlined,
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AlimSpace.lg,
                      AlimSpace.sm,
                      AlimSpace.lg,
                      AlimSpace.sm,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.fromUser;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AlimSpace.sm),
                          padding: const EdgeInsets.all(AlimSpace.md),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: mine
                                ? AlimColors.leafSoft.withValues(
                                    alpha: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.14
                                        : 1,
                                  )
                                : AlimColors.card(context),
                            borderRadius:
                                BorderRadius.circular(AlimRadius.card),
                            border: Border.all(
                              color: mine
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.25)
                                  : AlimColors.hairlineOf(context),
                            ),
                          ),
                          child: Text(
                            m.text,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AlimSpace.lg,
                      AlimSpace.xs,
                      AlimSpace.lg,
                      AlimSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Ask about what you are reading',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AlimSpace.xs),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
