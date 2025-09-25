// Reusable category tile with publish/unpublish visual state (badge + icon) and accessible tooltips.
import 'package:flutter/material.dart';

class CategoryTile extends StatelessWidget {
  final String code;
  final String descriptionOrUpdatedText;
  final bool isPublished;
  final String? statusLabel;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const CategoryTile({
    super.key,
    required this.code,
    required this.descriptionOrUpdatedText,
    required this.isPublished,
    this.statusLabel,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (code.isNotEmpty ? code[0] : '?').toUpperCase();
    final publishedText =
        statusLabel ?? (isPublished ? 'Publié' : 'Non publié');

    final statusChip = Chip(
      label: Text(publishedText),
      avatar: Icon(
        isPublished ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        size: 18,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final leadingAvatar = CircleAvatar(child: Text(initial));

    return ListTile(
      leading: leadingAvatar,
      title: Row(
        children: [
          Expanded(
            child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: publishedText,
            child: Icon(
              isPublished
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 18,
            ),
          ),
        ],
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
