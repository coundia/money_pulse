// File provides a smooth branded AppBar with centered title, vivid green gradient,
// adjustable green banner height, blur, rounded bottom, busy state, and a tappable monogram.
import 'dart:ui';
import 'package:flutter/material.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool busy;

  /// Tap on the centered title area
  final VoidCallback? onTapTitle;

  /// Tap on the left brand monogram (e.g., open SettingsPage)
  final VoidCallback? onTapMonogram;

  /// Bottom curve radius
  final double bottomRadius;

  /// Toolbar content height (excludes banner & progress)
  final double height;

  /// Extra green space under the bar (keeps the curved style)
  final double bannerHeight;

  const BrandAppBar({
    super.key,
    required this.title,
    this.actions,
    this.busy = false,
    this.onTapTitle,
    this.onTapMonogram,
    this.bottomRadius = 24,
    this.height = kToolbarHeight,
    this.bannerHeight = 0,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(height + bannerHeight + (busy ? 3 : 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Brand gradient
    final c1 = isDark ? const Color(0xFF0E7052) : const Color(0xFF1FD57F);
    final c2 = isDark ? const Color(0xFF0CA06C) : const Color(0xFF14B974);
    final overlay = isDark
        ? Colors.black.withOpacity(.10)
        : Colors.white.withOpacity(.06);

    // Painted height must include curve + banner to avoid overflow
    final paintedHeight = height + bottomRadius + bannerHeight + 40;

    return ClipPath(
      clipper: _BottomCurveClipper(radius: bottomRadius),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Gradient background
            Container(
              height: paintedHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1, c2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Subtle blur/overlay for depth
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(height: paintedHeight, color: overlay),
            ),
            // Content
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Centered title (tappable)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onTapTitle,
                            child: DefaultTextStyle(
                              style: theme.textTheme.titleLarge!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                              child: IconTheme(
                                data: const IconThemeData(color: Colors.white),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: title,
                                ),
                              ),
                            ),
                          ),

                          // Left monogram (tappable to open Settings, etc.)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: onTapMonogram,
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Center(
                                    child: _BrandMonogram(size: 28),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Right actions
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _wrapActions(theme, actions),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Optional green banner to extend the color under the curve
                  if (bannerHeight > 0) SizedBox(height: bannerHeight),

                  // Busy indicator
                  if (busy)
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _wrapActions(ThemeData theme, List<Widget>? actions) {
    if (actions == null || actions.isEmpty) return const [];
    return actions
        .map(
          (w) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Theme(
              data: theme.copyWith(
                iconTheme: const IconThemeData(color: Colors.white),
                popupMenuTheme: theme.popupMenuTheme.copyWith(
                  color: theme.colorScheme.surface,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              child: w,
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  final double radius;
  _BottomCurveClipper({required this.radius});

  @override
  Path getClip(Size size) {
    final r = radius.clamp(0, 56);
    final path = Path()..lineTo(0, size.height - r);
    path.quadraticBezierTo(
      size.width * .5,
      size.height + r,
      size.width,
      size.height - r,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _BottomCurveClipper oldClipper) =>
      oldClipper.radius != radius;
}

class _BrandMonogram extends StatelessWidget {
  final double size;
  const _BrandMonogram({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        gradient: LinearGradient(
          colors: [Color(0xFF1FD57F), Color(0xFF14B974)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'JK',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
