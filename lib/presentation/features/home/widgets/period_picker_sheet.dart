import 'package:flutter/material.dart';

import '../../transactions/models/transaction_filters.dart';

/// Bottom sheet pour choisir la période d’affichage (Weekly / Monthly / Yearly).
/// Retourne la valeur sélectionnée (ou null si annulé).
Future<Period?> showPeriodPickerSheet({
  required BuildContext context,
  required Period current,
}) {
  return showModalBottomSheet<Period>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('Période', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.view_week),
            title: const Text('Semaine'),
            trailing: current == Period.weekly ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, Period.weekly),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Mois'),
            trailing: current == Period.monthly
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(ctx, Period.monthly),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Année'),
            trailing: current == Period.yearly ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, Period.yearly),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
