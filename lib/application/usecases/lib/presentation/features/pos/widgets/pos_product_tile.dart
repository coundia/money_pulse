import 'package:flutter/material.dart';

class PosProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PosProductTile({
    super.key,
    required this.title,
    required this.priceCents,
    required this.onTap,
    this.subtitle,
    this.onLongPress,
  });

  String _money(int c) => (c ~/ 100).toString();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.35),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text(title.isNotEmpty ? title[0].toUpperCase() : '?'),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _money(priceCents),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
