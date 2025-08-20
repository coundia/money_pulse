/// Context menu model and builder for savings goals.

import 'package:flutter/material.dart';

enum SavingGoalMenuAction {
  view,
  edit,
  adjust,
  archive,
  unarchive,
  delete,
  share,
}

class SavingGoalContextMenu {
  static List<PopupMenuEntry<SavingGoalMenuAction>> build({
    required bool isArchived,
    required VoidCallback? onPreview,
  }) {
    return [
      PopupMenuItem(
        value: SavingGoalMenuAction.view,
        child: const Text('Voir'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: SavingGoalMenuAction.edit,
        child: const Text('Modifier'),
      ),
      PopupMenuItem(
        value: SavingGoalMenuAction.adjust,
        child: const Text('Ajuster l’épargne'),
      ),
      PopupMenuItem(
        value: isArchived
            ? SavingGoalMenuAction.unarchive
            : SavingGoalMenuAction.archive,
        child: Text(isArchived ? 'Désarchiver' : 'Archiver'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: SavingGoalMenuAction.share,
        child: const Text('Partager'),
      ),
      PopupMenuItem(
        value: SavingGoalMenuAction.delete,
        child: const Text('Supprimer'),
      ),
    ];
  }
}
