import 'dart:async';
import 'package:flutter/material.dart';

/// Pops the current route safely after the current frame to avoid !_debugLocked.
/// Returns [result] to the awaiting caller (typed via the generic).
Future<void> popAfterFrame<T>(BuildContext context, [T? result]) async {
  // Close keyboard/overlays
  FocusManager.instance.primaryFocus?.unfocus();

  // Let overlays (Dropdown, menus) finish their own push/pop
  await Future<void>.delayed(const Duration(milliseconds: 16));
  if (!context.mounted) return;

  final local = Navigator.of(context);
  if (local.canPop()) {
    local.pop<T>(result);
    return;
  }

  // Fallback to root if the drawer was pushed there
  final root = Navigator.of(context, rootNavigator: true);
  if (root.canPop()) {
    root.pop<T>(result);
  }
}

String? validateEmail(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
  return ok ? null : 'Email invalide';
}
