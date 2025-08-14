import 'package:flutter/material.dart';

class TypeToggle extends StatelessWidget {
  final bool isDebit;
  final ValueChanged<bool> onChanged;
  const TypeToggle({super.key, required this.isDebit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isDebit ? cs.error : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isDebit ? Icons.south : Icons.north, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.south),
                  label: Text('Dépense'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.north),
                  label: Text('Revenu'),
                ),
              ],
              selected: {isDebit},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(isDebit ? 'Dépense' : 'Revenu'),
            avatar: Icon(
              isDebit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
