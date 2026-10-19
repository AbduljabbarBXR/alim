import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The work half of the app: a plain, honest task list beside the worship.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  final _title = TextEditingController();
  String? _due;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _title.text.trim();
    if (text.isEmpty) return;
    await ref.read(actionsProvider).addTodo(text, due: _due);
    _title.clear();
    setState(() => _due = null);
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due == null ? now : DateTime.parse(_due!),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _due = dayKey(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoProvider);
    final items = todos.valueOrNull ?? const <Todo>[];
    final open = items.where((t) => !t.done).toList();
    final done = items.where((t) => t.done).toList();
    final today = dayKey(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('My tasks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AlimSpace.lg,
          AlimSpace.xs,
          AlimSpace.lg,
          AlimSpace.xxl,
        ),
        children: [
          AlimCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'What needs doing?',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Set a date',
                        icon: Icon(
                          _due == null
                              ? Icons.event_outlined
                              : Icons.event_available,
                          color: _due == null ? null : AlimColors.gold,
                        ),
                        onPressed: _pickDue,
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: AlimSpace.xs),
                IconButton.filled(
                  tooltip: 'Add',
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (_due != null)
            Padding(
              padding: const EdgeInsets.only(top: AlimSpace.xs),
              child: AlimPill(
                label: 'Due $_due',
                color: AlimColors.gold,
                icon: Icons.event,
              ),
            ),
          const SectionHeader('Open'),
          if (open.isEmpty)
            const EmptyNote(
              text: 'Nothing open. Work is worship when it is honest. Add '
                  'what today asks of you.',
              icon: Icons.task_alt,
            )
          else
            for (final t in open)
              _TodoTile(
                todo: t,
                overdue: t.due != null && t.due!.compareTo(today) < 0,
                dueToday: t.due == today,
              ),
          if (done.isNotEmpty) ...[
            const SectionHeader('Done'),
            for (final t in done) _TodoTile(todo: t, overdue: false, dueToday: false),
          ],
        ],
      ),
    );
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({
    required this.todo,
    required this.overdue,
    required this.dueToday,
  });

  final Todo todo;
  final bool overdue;
  final bool dueToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AlimSpace.xs),
      child: AlimCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AlimSpace.sm,
          vertical: 2,
        ),
        child: Row(
          children: [
            Checkbox(
              value: todo.done,
              onChanged: (_) =>
                  ref.read(actionsProvider).toggleTodo(todo.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      decoration:
                          todo.done ? TextDecoration.lineThrough : null,
                      color: todo.done ? AlimColors.mutedOf(context) : null,
                    ),
                  ),
                  if (todo.due != null && !todo.done)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AlimPill(
                        label: overdue
                            ? 'Overdue · ${todo.due}'
                            : dueToday
                                ? 'Today'
                                : 'Due ${todo.due}',
                        color: overdue
                            ? AlimColors.rose
                            : dueToday
                                ? AlimColors.gold
                                : AlimColors.mutedOf(context),
                        icon: Icons.event,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 19),
              onPressed: () => ref.read(actionsProvider).deleteTodo(todo.id),
            ),
          ],
        ),
      ),
    );
  }
}
