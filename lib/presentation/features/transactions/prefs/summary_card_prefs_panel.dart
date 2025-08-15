// Right-drawer panel to configure which sections of TransactionSummaryCard are visible.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prefs/summary_card_prefs_provider.dart';

class SummaryCardPrefsPanel extends ConsumerWidget {
  const SummaryCardPrefsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(summaryCardPrefsProvider);
    final ctrl = ref.read(summaryCardPrefsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Personnalisation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              title: const Text('Afficher les actions rapides'),
              value: prefs.showQuickActions,
              onChanged: (v) => ctrl.setShowQuickActions(v),
            ),
            SwitchListTile.adaptive(
              title: const Text('Bouton Dépense'),
              value: prefs.showExpenseButton,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowExpenseButton(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),
            SwitchListTile.adaptive(
              title: const Text('Bouton Revenu'),
              value: prefs.showIncomeButton,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowIncomeButton(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              title: const Text('Afficher l’entête de période'),
              value: prefs.showPeriodHeader,
              onChanged: (v) => ctrl.setShowPeriodHeader(v),
            ),
            SwitchListTile.adaptive(
              title: const Text('Afficher les métriques'),
              value: prefs.showMetrics,
              onChanged: (v) => ctrl.setShowMetrics(v),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => ctrl.reset(),
              child: const Text('Réinitialiser'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
