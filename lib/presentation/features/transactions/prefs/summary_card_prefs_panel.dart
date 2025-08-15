// Right-drawer panel to configure which sections of TransactionSummaryCard are visible, plus bottom navigation visibility.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../prefs/summary_card_prefs_provider.dart';
import 'package:money_pulse/presentation/features/home/prefs/home_ui_prefs_provider.dart';

class SummaryCardPrefsPanel extends ConsumerWidget {
  const SummaryCardPrefsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(summaryCardPrefsProvider);
    final ctrl = ref.read(summaryCardPrefsProvider.notifier);

    final uiPrefs = ref.watch(homeUiPrefsProvider);
    final uiCtrl = ref.read(homeUiPrefsProvider.notifier);

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

            const Divider(height: 24),

            SwitchListTile.adaptive(
              title: const Text('Afficher la barre de navigation en bas'),
              value: uiPrefs.showBottomNav,
              onChanged: (v) => uiCtrl.setShowBottomNav(v),
            ),

            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                await ctrl.reset();
                await uiCtrl.reset();
              },
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
