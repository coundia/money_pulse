// lib/presentation/features/transactions/prefs/summary_card_prefs_panel.dart
// Right-drawer panel to configure SummaryCard sections and shortcuts,
// now with "Reset", "Tout cocher", and "Tout décocher" buttons at the top.

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

    Future<void> checkAll() async {
      // Active tout ce qui a du sens
      await ctrl.setShowQuickActions(true);
      await ctrl.setShowExpenseButton(true);
      await ctrl.setShowIncomeButton(true);
      await ctrl.setShowDebtButton(true);
      await ctrl.setShowRepaymentButton(true);
      await ctrl.setShowLoanButton(true);

      await ctrl.setShowNavShortcuts(true);
      await ctrl.setShowNavTransactionsButton(true);
      await ctrl.setShowNavPosButton(true);
      await ctrl.setShowNavSettingsButton(true);

      await ctrl.setShowNavSearchButton(true);
      await ctrl.setShowNavStockButton(true);
      await ctrl.setShowNavReportButton(true);
      await ctrl.setShowNavProductsButton(true);
      await ctrl.setShowNavCustomersButton(true);
      await ctrl.setShowNavCategoriesButton(true);
      await ctrl.setShowNavAccountsButton(true);

      await ctrl.setShowPeriodHeader(true);
      await ctrl.setShowMetrics(true);

      await ctrl.setShowNavMarketplaceButton(true);
      await ctrl.setShowNavChatbotButton(true);

      // (Optionnel) activer la bottom nav si vous le souhaitez aussi
      // await uiCtrl.setShowBottomNav(true);
    }

    Future<void> uncheckAll() async {
      // Désactive tout
      await ctrl.setShowQuickActions(false);
      await ctrl.setShowExpenseButton(false);
      await ctrl.setShowIncomeButton(false);
      await ctrl.setShowDebtButton(false);
      await ctrl.setShowRepaymentButton(false);
      await ctrl.setShowLoanButton(false);

      await ctrl.setShowNavShortcuts(false);
      await ctrl.setShowNavTransactionsButton(false);
      await ctrl.setShowNavPosButton(false);
      await ctrl.setShowNavSettingsButton(false);

      await ctrl.setShowNavSearchButton(false);
      await ctrl.setShowNavStockButton(false);
      await ctrl.setShowNavReportButton(false);
      await ctrl.setShowNavProductsButton(false);
      await ctrl.setShowNavCustomersButton(false);
      await ctrl.setShowNavCategoriesButton(false);
      await ctrl.setShowNavAccountsButton(false);

      await ctrl.setShowPeriodHeader(false);
      await ctrl.setShowMetrics(false);

      await ctrl.setShowNavMarketplaceButton(false);
      await ctrl.setShowNavChatbotButton(false);

      // (Optionnel) masquer la bottom nav
      // await uiCtrl.setShowBottomNav(false);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ---- Header + boutons d'action (TOP) ----
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Personnalisation',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Reset en premier
                FilledButton.tonal(
                  onPressed: () async {
                    await ctrl.reset();
                    await uiCtrl.reset();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Réglages réinitialisés.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Réinitialiser'),
                ),
                OutlinedButton.icon(
                  onPressed: uncheckAll,
                  icon: const Icon(Icons.remove_done),
                  label: const Text('Tout décocher'),
                ),
                FilledButton.icon(
                  onPressed: checkAll,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Tout cocher'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 24),

            // ---- Contenu existant ----
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
            SwitchListTile.adaptive(
              title: const Text('Bouton Dette'),
              value: prefs.showDebtButton,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowDebtButton(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),
            SwitchListTile.adaptive(
              title: const Text('Bouton Remboursement'),
              value: prefs.showRepaymentButton,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowRepaymentButton(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),
            SwitchListTile.adaptive(
              title: const Text('Bouton Prêt'),
              value: prefs.showLoanButton,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowLoanButton(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),

            const Divider(height: 24),

            SwitchListTile.adaptive(
              title: const Text('Afficher les raccourcis de navigation'),
              value: prefs.showNavShortcuts,
              onChanged: prefs.showQuickActions
                  ? (v) => ctrl.setShowNavShortcuts(v)
                  : null,
              subtitle: const Text('Dépend des actions rapides'),
            ),

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
              title: const Text('Marketplace'),
              value: prefs.showNavMarketplaceButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavMarketplaceButton(v)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Chatbot'),
              value: prefs.showNavChatbotButton,
              onChanged: prefs.showQuickActions && prefs.showNavShortcuts
                  ? (v) => ctrl.setShowNavChatbotButton(v)
                  : null,
            ),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
