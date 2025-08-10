import 'package:flutter/material.dart';

Future<T?> showLeftDrawer<T>(
  BuildContext context, {
  required Widget child,
  double widthFraction = 0.9,
  Duration duration = const Duration(milliseconds: 280),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: 'dismiss',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: duration,
    pageBuilder: (ctx, a1, a2) {
      final w = MediaQuery.of(ctx).size.width * widthFraction;
      final h = MediaQuery.of(ctx).size.height;
      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: w,
            height: h,
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
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
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
