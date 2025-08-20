/// Right-drawer read-only panel for a savings goal with quick actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class SavingGoalViewPanel extends ConsumerWidget {
  final SavingGoal goal;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjust;
  final VoidCallback? onArchiveToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const SavingGoalViewPanel({
    super.key,
    required this.goal,
    this.onEdit,
    this.onAdjust,
    this.onArchiveToggle,
    this.onDelete,
    this.onShare,
  });

  String _money(int c) => Formatters.amountFromCents(c);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = goal.isCompleted;
    final isArchived = goal.isArchived == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objectif d’épargne'),
        actions: [
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Partager',
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (_, c) {
          final isWide = c.maxWidth > 620;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isWide ? 24 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: goal.progress == 0 ? null : goal.progress,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_money(goal.savedCents)} / ${_money(goal.targetCents)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (goal.description?.isNotEmpty == true)
                      Text(goal.description!),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (goal.dueDate != null)
                          Chip(
                            label: Text(
                              'Échéance: ${Formatters.dateFull(goal.dueDate!)}',
                            ),
                          ),
                        if (isCompleted) const Chip(label: Text('Terminé')),
                        if (isArchived) const Chip(label: Text('Archivé')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onAdjust,
                          icon: const Icon(Icons.savings),
                          label: const Text('Ajuster l’épargne'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onArchiveToggle,
                          icon: Icon(
                            isArchived ? Icons.unarchive : Icons.archive,
                          ),
                          label: Text(isArchived ? 'Désarchiver' : 'Archiver'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
