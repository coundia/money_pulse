import 'package:flutter/material.dart';

class ProductInfoCompact extends StatelessWidget {
  final String name;
  final String priceStr;
  final String? description;
  final ThemeData theme;

  const ProductInfoCompact({
    super.key,
    required this.name,
    required this.priceStr,
    required this.theme,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2, top: 2, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              priceStr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            if ((description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
