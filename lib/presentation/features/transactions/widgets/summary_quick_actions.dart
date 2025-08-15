// Large-icon quick actions using SVG assets with SRP (palette, decoration, layout, and svg rendering separated).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            label: 'Dépense',
            svgAsset: 'assets/icons/expense_add.svg',
            tone: Theme.of(context).colorScheme.error,
            onPressed: onAddExpense,
          ),
          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
          _TonedFilledButton(
            label: 'Revenu',
            svgAsset: 'assets/icons/income_add.svg',
            tone: Theme.of(context).colorScheme.tertiary,
            onPressed: onAddIncome,
          ),
        ];
        return isNarrow ? Column(children: children) : Row(children: children);
      },
    );
  }
}

class _TonedFilledButton extends StatefulWidget {
  final String label;
  final String svgAsset;
  final Color tone;
  final VoidCallback? onPressed;

  const _TonedFilledButton({
    required this.label,
    required this.svgAsset,
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
    final palette = _Palette.from(context, widget.tone);
    final decoration = _DecorationBuilder.forStates(
      palette: palette,
      hovered: _hovered,
      focused: _focused,
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
              decoration: decoration,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: palette.fg.withOpacity(0.10),
                  highlightColor: palette.fg.withOpacity(0.06),
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
                          final iconSize = _Layout.iconSize(
                            constraints.maxWidth,
                          );
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SvgIcon(
                                asset: widget.svgAsset,
                                size: iconSize,
                                color: palette.fg,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: palette.fg,
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

class _SvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;

  const _SvgIcon({
    required this.asset,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
      fit: BoxFit.contain,
    );
  }
}

class _Palette {
  final Color bgA;
  final Color bgB;
  final Color fg;
  final Color base;
  final bool isDark;

  const _Palette({
    required this.bgA,
    required this.bgB,
    required this.fg,
    required this.base,
    required this.isDark,
  });

  factory _Palette.from(BuildContext context, Color tone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final h = HSLColor.fromColor(tone);
    final light = h
        .withLightness((h.lightness + (isDark ? 0.10 : 0.20)).clamp(0, 1))
        .toColor();
    final dark = h
        .withLightness((h.lightness - (isDark ? 0.10 : 0.05)).clamp(0, 1))
        .toColor();
    final bgA = isDark ? light.withOpacity(0.22) : light.withOpacity(0.18);
    final bgB = isDark ? dark.withOpacity(0.28) : dark.withOpacity(0.16);
    final fg = isDark ? tone.withOpacity(0.98) : tone.withOpacity(0.92);
    return _Palette(bgA: bgA, bgB: bgB, fg: fg, base: tone, isDark: isDark);
  }
}

class _DecorationBuilder {
  static BoxDecoration forStates({
    required _Palette palette,
    required bool hovered,
    required bool focused,
  }) {
    final radius = BorderRadius.circular(16);
    final hoveredOrFocused = hovered || focused;
    final boxShadow = hoveredOrFocused
        ? [
            BoxShadow(
              color: palette.base.withOpacity(palette.isDark ? 0.26 : 0.20),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];
    final border = Border.all(
      color: hoveredOrFocused
          ? palette.fg.withOpacity(0.45)
          : Colors.transparent,
      width: hoveredOrFocused ? 1.2 : 0,
    );
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.bgA, palette.bgB],
      ),
      borderRadius: radius,
      border: border,
      boxShadow: boxShadow,
    );
  }
}

class _Layout {
  static double iconSize(double width) {
    if (width < 140) return 48;
    if (width < 180) return 56;
    return 64;
  }
}
