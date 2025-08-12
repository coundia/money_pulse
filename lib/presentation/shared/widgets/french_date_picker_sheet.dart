import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> showFrenchDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  required void Function(DateTime) onApply,
  VoidCallback? onThisPeriod,
}) async {
  firstDate ??= DateTime(2000);
  lastDate ??= DateTime(2100);
  DateTime temp = initialDate;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) {
      final sheetHeight = MediaQuery.of(ctx).size.height * 0.75;

      return Localizations.override(
        context: ctx,
        locale: const Locale('fr', 'FR'),
        delegates: GlobalMaterialLocalizations.delegates,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
                child: Row(
                  children: [
                    Text(
                      'Sélectionner la date',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Fermer',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Contenu scrollable (calendrier)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Center(
                    child: CalendarDatePicker(
                      initialDate: initialDate,
                      firstDate: firstDate!,
                      lastDate: lastDate!,
                      onDateChanged: (d) => temp = d,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Boutons en 2 lignes
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                child: Column(
                  children: [
                    // Ligne 1 : rapides
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              temp = DateTime.now();
                              onApply(temp);
                              Navigator.of(ctx).pop();
                            },
                            icon: const Icon(Icons.today),
                            label: const Text('Aujourd’hui'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ligne 2 : actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              onApply(temp);
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Appliquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
