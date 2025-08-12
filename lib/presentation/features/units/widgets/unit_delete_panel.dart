import 'package:flutter/material.dart';
import 'package:money_pulse/domain/units/entities/unit.dart';

class UnitDeletePanel extends StatelessWidget {
  final Unit unit;
  const UnitDeletePanel({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    final title = unit.name?.isNotEmpty == true ? unit.name! : unit.code;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer l’unité'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Supprimer « $title » ?',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Cette action déplace l’unité dans la corbeille (suppression logique).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
