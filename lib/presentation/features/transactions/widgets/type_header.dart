import 'package:flutter/material.dart';

class TypeHeader extends StatelessWidget {
  final bool isDebit;
  const TypeHeader({super.key, required this.isDebit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isDebit ? cs.error : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Spacer(),
          Icon(isDebit ? Icons.south : Icons.north, color: accent),
          const SizedBox(width: 8),
          Text(
            isDebit ? 'Dépense' : 'Revenu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
