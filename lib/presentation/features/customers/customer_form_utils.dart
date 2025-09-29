import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pops after transitions settle, avoiding !_debugLocked.
/// - waits for endOfFrame
/// - posts pop on the next frame & microtask
/// - prefers local Navigator, falls back to root
Future<void> safePop<T>(BuildContext context, [T? result]) async {
  if (!context.mounted) return;

  // Dismiss keyboard/overlays
  FocusManager.instance.primaryFocus?.unfocus();

  // Let any ongoing push/pop animations finish
  try {
    await SchedulerBinding.instance.endOfFrame;
  } catch (_) {}

  if (!context.mounted) return;

  // Schedule for the next frame to be extra safe
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;

    // Only pop if this route is current (avoid background routes)
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final local = Navigator.of(context);
    final doPop = () {
      if (local.canPop()) {
        local.pop<T>(result);
      } else {
        final root = Navigator.of(context, rootNavigator: true);
        if (root.canPop()) root.pop<T>(result);
      }
    };

    // Push the actual pop to a microtask so we're outside build/layout
    scheduleMicrotask(doPop);
  });
}

String? validateEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  return ok ? null : 'Email invalide';
}
