import 'package:flutter/material.dart';

class StockBadgeOverlay extends StatelessWidget {
  final Widget child;
  final int? badgeValue;

  const StockBadgeOverlay({
    super.key,
    required this.child,
    required this.badgeValue,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeValue == null) return child;

    final positive = (badgeValue ?? 0) > 0;
    final bg = positive
        ? Colors.green.withOpacity(.12)
        : Colors.red.withOpacity(.12);
    final fg = positive ? Colors.green.shade800 : Colors.red.shade700;
    final text = positive ? 'Stock: $badgeValue' : 'Rupture';

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 56.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
