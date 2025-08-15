// Quick actions with large stacked icons and optional per-button visibility flags.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SummaryQuickActions extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;
  final bool showExpenseButton;
  final bool showIncomeButton;

  const SummaryQuickActions({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    this.showExpenseButton = true,
    this.showIncomeButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    if (showExpenseButton) {
      tiles.add(
        _TonedFilledButton(
          label: 'Dépense',
          icon: Icons.trending_down_rounded,
          tone: Theme.of(context).colorScheme.error,
          onPressed: onAddExpense,
        ),
      );
    }
    if (showIncomeButton) {
      if (tiles.isNotEmpty)
        tiles.add(
          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
        );
      tiles.add(
        _TonedFilledButton(
          label: 'Revenu',
          icon: Icons.trending_up_rounded,
          tone: Theme.of(context).colorScheme.tertiary,
          onPressed: onAddIncome,
        ),
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();
    return isNarrow ? Column(children: tiles) : Row(children: tiles);
  }
}

class _TonedFilledButton extends StatefulWidget {
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
  State<_TonedFilledButton> createState() => _TonedFilledButtonState();
}

class _TonedFilledButtonState extends State<_TonedFilledButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = widget.tone;
    final hsl = HSLColor.fromColor(base);
    final light = hsl
        .withLightness((hsl.lightness + (isDark ? 0.10 : 0.20)).clamp(0, 1))
        .toColor();
    final dark = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.05)).clamp(0, 1))
        .toColor();
    final bgA = isDark ? light.withOpacity(0.22) : light.withOpacity(0.18);
    final bgB = isDark ? dark.withOpacity(0.28) : dark.withOpacity(0.16);
    final fg = isDark ? base.withOpacity(0.98) : base.withOpacity(0.92);
    final radius = BorderRadius.circular(16);
    final hoveredOrFocused = _hovered || _focused;

    final boxShadow = hoveredOrFocused
        ? [
            BoxShadow(
              color: base.withOpacity(isDark ? 0.26 : 0.20),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];

    final border = Border.all(
      color: hoveredOrFocused ? fg.withOpacity(0.45) : Colors.transparent,
      width: hoveredOrFocused ? 1.2 : 0,
    );

    return Expanded(
      child: FocusableActionDetector(
        mouseCursor: widget.onPressed == null
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: Semantics(
          button: true,
          label: widget.label,
          onTapHint: 'Créer une transaction',
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _pressed ? 0.98 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgA, bgB],
                ),
                borderRadius: radius,
                border: border,
                boxShadow: boxShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: radius,
                  splashColor: fg.withOpacity(0.10),
                  highlightColor: fg.withOpacity(0.06),
                  onHighlightChanged: (v) => setState(() => _pressed = v),
                  onTap: widget.onPressed == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          widget.onPressed!.call();
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 118),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 14,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final iconSize = w < 160 ? 44.0 : 56.0;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widget.icon, size: iconSize, color: fg),
                              const SizedBox(height: 10),
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
