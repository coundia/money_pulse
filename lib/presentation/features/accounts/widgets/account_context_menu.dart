// Context menu for account items with optional header and safe actions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

Future<void> showAccountContextMenu(
  BuildContext context,
  Offset globalPosition, {
  required bool canMakeDefault,
  required VoidCallback onView,
  VoidCallback? onMakeDefault,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onShare,
  bool confirmDelete = true,
  String? accountLabel,
  int? balanceCents,
  String? currency,
  DateTime? updatedAt,
}) async {
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox;

  final header =
      (accountLabel != null || balanceCents != null || updatedAt != null)
      ? PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(accountLabel ?? 'Compte'),
            subtitle: updatedAt == null
                ? null
                : Text('Mis à jour: ${Formatters.dateFull(updatedAt)}'),
            trailing: (balanceCents == null)
                ? null
                : Text(
                    Formatters.amountFromCents(balanceCents) +
                        (currency != null ? ' $currency' : ''),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        )
      : null;

  final items = <PopupMenuEntry<String>>[
    if (header != null) header,
    if (header != null) const PopupMenuDivider(height: 6),
    const PopupMenuItem(
      value: 'view',
      child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Voir les détails'),
      ),
    ),
    if (canMakeDefault)
      const PopupMenuItem(
        value: 'default',
        child: ListTile(
          leading: Icon(Icons.star_border),
          title: Text('Définir par défaut'),
        ),
      ),
    const PopupMenuItem(
      value: 'edit',
      child: ListTile(
        leading: Icon(Icons.edit_outlined),
        title: Text('Modifier'),
      ),
    ),
    const PopupMenuItem(
      value: 'share',
      child: ListTile(
        leading: Icon(Icons.copy_all_outlined),
        title: Text('Copier les détails'),
      ),
    ),
    const PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: Icon(Icons.delete_outline),
        title: Text('Supprimer'),
      ),
    ),
  ];

  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlayBox.size.width - globalPosition.dx,
      overlayBox.size.height - globalPosition.dy,
    ),
    items: items,
  );

  if (result == null) return;

  HapticFeedback.selectionClick();

  switch (result) {
    case 'view':
      onView();
      break;
    case 'default':
      onMakeDefault?.call();
      break;
    case 'edit':
      onEdit();
      break;
    case 'share':
      onShare();
      break;
    case 'delete':
      if (!confirmDelete) {
        onDelete();
        break;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
            'Supprimer ce compte ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
      if (ok == true) onDelete();
      break;
  }
}
