// Responsive quick actions: auto-wrap grid with adaptive button sizing for many items, large icon stacked above label.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/features/transactions/pages/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/pos/pos_page.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';

class SummaryQuickActions extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  final bool showExpenseButton;
  final bool showIncomeButton;

  final bool showNavShortcuts;
  final bool showNavTransactionsButton;
  final bool showNavPosButton;
  final bool showNavSettingsButton;

  final VoidCallback? onOpenTransactions;
  final VoidCallback? onOpenPos;
  final VoidCallback? onOpenSettings;

  const SummaryQuickActions({
    super.key,
    required this.onAddExpense,
    required this.onAddIncome,
    this.showExpenseButton = true,
    this.showIncomeButton = true,
    this.showNavShortcuts = true,
    this.showNavTransactionsButton = true,
    this.showNavPosButton = true,
    this.showNavSettingsButton = true,
    this.onOpenTransactions,
    this.onOpenPos,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final buttons = <Widget>[];
        if (showExpenseButton) {
          buttons.add(
            _TonedFilledButton(
              label: 'Dépense',
              icon: Icons.trending_down_rounded,
              tone: Theme.of(context).colorScheme.error,
              onPressed: onAddExpense,
            ),
          );
        }
        if (showIncomeButton) {
          buttons.add(
            _TonedFilledButton(
              label: 'Revenu',
              icon: Icons.trending_up_rounded,
              tone: Theme.of(context).colorScheme.tertiary,
              onPressed: onAddIncome,
            ),
          );
        }

        if (showNavShortcuts) {
          if (showNavTransactionsButton) {
            buttons.add(
              _TonedFilledButton(
                label: 'Transactions',
                icon: Icons.list_alt,
                tone: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (onOpenTransactions != null) {
                    onOpenTransactions!();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionListPage(),
                      ),
                    );
                  }
                },
              ),
            );
          }
          if (showNavPosButton) {
            buttons.add(
              _TonedFilledButton(
                label: 'POS',
                icon: Icons.point_of_sale,
                tone: Theme.of(context).colorScheme.secondary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (onOpenPos != null) {
                    onOpenPos!();
                  } else {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const PosPage()));
                  }
                },
              ),
            );
          }
          if (showNavSettingsButton) {
            buttons.add(
              _TonedFilledButton(
                label: 'Paramètres',
                icon: Icons.settings,
                tone: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (onOpenSettings != null) {
                    onOpenSettings!();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  }
                },
              ),
            );
          }
        }

        if (buttons.isEmpty) return const SizedBox.shrink();

        final spacing = 12.0;
        final w = c.maxWidth;
        final cols = _columnsForWidth(w);
        final itemWidth = ((w - (spacing * (cols - 1))) / cols).clamp(
          120.0,
          360.0,
        );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: buttons
              .map((b) => SizedBox(width: itemWidth as double, child: b))
              .toList(growable: false),
        );
      },
    );
  }

  static int _columnsForWidth(double w) {
    if (w >= 1040) return 5;
    if (w >= 840) return 4;
    if (w >= 600) return 3;
    if (w >= 360) return 2;
    return 1;
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

    return FocusableActionDetector(
      mouseCursor: widget.onPressed == null
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      child: Semantics(
        button: true,
        label: widget.label,
        onTapHint: 'Ouvrir',
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cw = constraints.maxWidth;
                    final dense = cw < 150;
                    final iconSize = cw < 150 ? 36.0 : (cw < 200 ? 44.0 : 56.0);
                    final fontSize = cw < 150 ? 12.0 : 14.0;
                    final padV = cw < 150 ? 12.0 : 16.0;
                    final minH = cw < 150 ? 88.0 : 118.0;

                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minH),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: padV,
                          horizontal: 14,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, size: iconSize, color: fg),
                            const SizedBox(height: 8),
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              maxLines: dense ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: fontSize,
                                color: fg,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
