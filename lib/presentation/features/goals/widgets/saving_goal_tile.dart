/// Reusable list tile for a savings goal with progress and context menu.

import 'package:flutter/material.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/features/goals/widgets/saving_goal_context_menu.dart';

class SavingGoalTile extends StatelessWidget {
  final SavingGoal goal;
  final VoidCallback? onTap;
  final void Function(SavingGoalMenuAction action)? onMenu;

  const SavingGoalTile({
    super.key,
    required this.goal,
    this.onTap,
    this.onMenu,
  });

  String _money(int cents) => '${Formatters.amountFromCents(cents)}';

  @override
  Widget build(BuildContext context) {
    final isCompleted = goal.isCompleted;
    final isArchived = goal.isArchived == 1;

    final title = Text(
      goal.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        decoration: isArchived ? TextDecoration.lineThrough : null,
      ),
    );

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: goal.progress == 0 ? null : goal.progress,
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('${_money(goal.savedCents)} / ${_money(goal.targetCents)}'),
            if (goal.dueDate != null)
              Text('Échéance: ${Formatters.dateFull(goal.dueDate!)}'),
            if (isCompleted) const Chip(label: Text('Terminé')),
            if (isArchived) const Chip(label: Text('Archivé')),
          ],
        ),
      ],
    );

    final trailing = PopupMenuButton<SavingGoalMenuAction>(
      tooltip: 'Menu',
      itemBuilder: (ctx) =>
          SavingGoalContextMenu.build(isArchived: isArchived, onPreview: onTap),
      onSelected: (a) => onMenu?.call(a),
    );

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
