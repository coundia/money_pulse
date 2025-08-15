// Right-drawer panel to configure TransactionSummaryCard sections and extended nav shortcuts.
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

            // Quick actions
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

            // Nav shortcuts group
            SwitchListTile.adaptive(
              title: const Text('Afficher les raccourcis de navigation'),
              value: prefs.showNavShortcuts,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowNavShortcuts(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),
            // Core
            SwitchListTile.adaptive(
              title: const Text('Transactions'),
              value: prefs.showNavTransactionsButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavTransactionsButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('POS'),
              value: prefs.showNavPosButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavPosButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Paramètres'),
              value: prefs.showNavSettingsButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavSettingsButton(v)
                  : null,
            ),

            // New extended shortcuts (all hidden by default)
            const Divider(height: 24),
            Text(
              'Raccourcis supplémentaires',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            SwitchListTile.adaptive(
              title: const Text('Recherche (transactions)'),
              value: prefs.showNavSearchButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavSearchButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Stock'),
              value: prefs.showNavStockButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavStockButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Rapport'),
              value: prefs.showNavReportButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavReportButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Produits'),
              value: prefs.showNavProductsButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavProductsButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Clients'),
              value: prefs.showNavCustomersButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavCustomersButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Catégories'),
              value: prefs.showNavCategoriesButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavCategoriesButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Comptes'),
              value: prefs.showNavAccountsButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavAccountsButton(v)
                  : null,
            ),

            const Divider(height: 24),

            // Other sections
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
