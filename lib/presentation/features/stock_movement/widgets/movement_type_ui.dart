// Small helper for mapping stock movement type to French label, icon and themed color.
import 'package:flutter/material.dart';

class MovementTypeUi {
  static const allKey = 'ALL';
  static const values = ['ALL', 'IN', 'OUT', 'ALLOCATE', 'RELEASE', 'ADJUST'];

  static String fr(String t) {
    switch (t) {
      case 'IN':
        return 'Entrée';
      case 'OUT':
        return 'Sortie';
      case 'ALLOCATE':
        return 'Allocation';
      case 'RELEASE':
        return 'Libération';
      case 'ADJUST':
        return 'Ajustement';
      case 'ALL':
      default:
        return 'Tous';
    }
  }

  static IconData icon(String t) {
    switch (t) {
      case 'IN':
        return Icons.call_received;
      case 'OUT':
        return Icons.call_made;
      case 'ALLOCATE':
        return Icons.inventory_2_outlined;
      case 'RELEASE':
        return Icons.inventory_outlined;
      case 'ADJUST':
        return Icons.tune;
      default:
        return Icons.all_inbox;
    }
  }

  static Color color(BuildContext ctx, String t) {
    final cs = Theme.of(ctx).colorScheme;
    switch (t) {
      case 'IN':
        return cs.primary;
      case 'OUT':
        return cs.error;
      case 'ALLOCATE':
        return cs.tertiary;
      case 'RELEASE':
        return cs.secondary;
      case 'ADJUST':
        return cs.outline;
      default:
        return cs.onSurfaceVariant;
    }
  }
}
