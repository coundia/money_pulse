import 'package:flutter/material.dart';

Future<T?> showRightDrawer<T>(
  BuildContext context, {
  required Widget child,
  double widthFraction = 0.86,
  double heightFraction = 1.0,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: duration,
    pageBuilder: (ctx, a1, a2) {
      final size = MediaQuery.of(ctx).size;
      final w = size.width * widthFraction;
      final h = size.height * heightFraction;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: w,
            height: h,
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              elevation: 12,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(child: child),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, sec, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
