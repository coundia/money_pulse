// lib/presentation/features/transactions/detail/widgets/header_card.dart

import 'package:flutter/material.dart';
import 'pills.dart';

class HeaderCard extends StatelessWidget {
  final Tone tone;
  final String amountText;
  final String dateText;
  final String? status;
  final bool accountless;

  const HeaderCard({
    super.key,
    required this.tone,
    required this.amountText,
    required this.dateText,
    required this.status,
    required this.accountless,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(tone.color);
    final c1 = hsl
        .withLightness((hsl.lightness + (isDark ? 0.12 : 0.20)).clamp(0, 1))
        .toColor();
    final c2 = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.06)).clamp(0, 1))
        .toColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [c1.withOpacity(0.18), c2.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: tone.color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tone.color.withOpacity(0.15),
            child: Icon(tone.icon, color: tone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TypePill(label: tone.label, color: tone.color),
                    StatusPill(status: status, tone: tone),
                    if (accountless)
                      TypePillSmall(label: 'Hors compte', color: tone.color),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  amountText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tone.color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 6),
                    Text(dateText),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
