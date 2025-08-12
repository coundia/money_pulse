import 'package:flutter/material.dart';

enum CustomerMenuAction { view, edit, delete }

class CustomerContextMenu extends StatelessWidget {
  final void Function(CustomerMenuAction action) onSelected;

  const CustomerContextMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CustomerMenuAction>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: CustomerMenuAction.view,
          child: _MenuRow(icon: Icons.visibility_outlined, label: 'Voir'),
        ),
        const PopupMenuItem(
          value: CustomerMenuAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Modifier'),
        ),
        const PopupMenuItem(
          value: CustomerMenuAction.delete,
          child: _MenuRow(icon: Icons.delete_outline, label: 'Supprimer'),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}
