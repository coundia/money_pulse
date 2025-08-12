import 'package:flutter/material.dart';

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;
  final EdgeInsetsGeometry padding;

  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 140,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
