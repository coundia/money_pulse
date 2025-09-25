// Reusable list tile for Category with optional trailing menu button.
import 'package:flutter/material.dart';

class CategoryTile extends StatelessWidget {
  final String code;
  final String descriptionOrUpdatedText;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const CategoryTile({
    super.key,
    required this.code,
    required this.descriptionOrUpdatedText,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (code.isNotEmpty ? code[0] : '?').toUpperCase();
    return ListTile(
      leading: CircleAvatar(child: Text(initial)),
      title: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        descriptionOrUpdatedText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: onMore,
        tooltip: 'Actions',
      ),
      onTap: onTap,
    );
  }
}
