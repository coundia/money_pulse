// Small utility to unify haptic feedback patterns across the app.
import 'package:flutter/services.dart';

class HapticsUtil {
  static Future<void> tapLight() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> tapMedium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> tapHeavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static Future<void> select() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> success() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  static Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
