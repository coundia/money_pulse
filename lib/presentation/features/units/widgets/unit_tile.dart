import 'package:flutter/material.dart';

class UnitTile extends StatelessWidget {
  final String code;
  final String? name;
  final String? subtitle;
  final VoidCallback? onTap;

  /// 'view' | 'edit' | 'delete' | 'share'
  final Future<void> Function(String action)? onMenuAction;

  const UnitTile({
    super.key,
    required this.code,
    this.name,
    this.subtitle,
    this.onTap,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final title = (name?.isNotEmpty == true) ? '$name' : code;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(
          (title.isNotEmpty ? title.characters.first : '?').toUpperCase(),
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(subtitle!),
      trailing: onMenuAction == null
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) async => onMenuAction!(v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('Voir'),
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.ios_share),
                    title: Text('Partager'),
                  ),
                ),
              ],
            ),
    );
  }
}
