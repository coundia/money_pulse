// Metric chip showing a label and a colored value with accessibility semantics.
import 'package:flutter/material.dart';

class SummaryMetricChip extends StatelessWidget {
  final String label;
  final String valueText;
  final Color tone;
  final String? semanticsValue;

  const SummaryMetricChip({
    super.key,
    required this.label,
    required this.valueText,
    required this.tone,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? tone.withOpacity(0.20) : tone.withOpacity(0.12));
    final fg = isDark ? tone.withOpacity(0.95) : tone.withOpacity(0.90);

    return Semantics(
      label: label,
      value: semanticsValue ?? valueText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              valueText,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
