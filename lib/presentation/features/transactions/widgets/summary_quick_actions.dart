// Quick action buttons for adding expense and income with toned visuals.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SummaryQuickActions extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const SummaryQuickActions({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isNarrow = c.maxWidth < 360;
        final children = <Widget>[
          _TonedFilledButton(
            label: 'Ajouter dépense',
            icon: Icons.remove_circle_outline,
            tone: Theme.of(context).colorScheme.error,
            onPressed: onAddExpense,
          ),
          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
          _TonedFilledButton(
            label: 'Ajouter revenu',
            icon: Icons.add_circle_outline,
            tone: Theme.of(context).colorScheme.tertiary,
            onPressed: onAddIncome,
          ),
        ];
        return isNarrow ? Column(children: children) : Row(children: children);
      },
    );
  }
}

class _TonedFilledButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback? onPressed;

  const _TonedFilledButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? tone.withOpacity(0.20) : tone.withOpacity(0.12));
    final fg = isDark ? tone.withOpacity(0.95) : tone.withOpacity(0.90);

    return Expanded(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: FilledButton.icon(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!.call();
                },
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style:
              FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: bg,
                foregroundColor: fg,
                disabledForegroundColor: fg.withOpacity(0.38),
                disabledBackgroundColor: bg.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ).merge(
                ButtonStyle(
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return fg.withOpacity(0.08);
                    }
                    if (states.contains(MaterialState.hovered) ||
                        states.contains(MaterialState.focused)) {
                      return fg.withOpacity(0.06);
                    }
                    return null;
                  }),
                  animationDuration: const Duration(milliseconds: 120),
                ),
              ),
        ),
      ),
    );
  }
}
