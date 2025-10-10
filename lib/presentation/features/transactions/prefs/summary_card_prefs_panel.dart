// lib/presentation/features/transactions/prefs/summary_card_prefs_panel.dart
// Right-drawer panel to configure SummaryCard sections and shortcuts,
// with "Tout cocher" / "Tout décocher" at the top and "Réinitialiser" at the bottom.
// Wrapped in a Scaffold to ensure SnackBars can be shown safely.

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
    }

    Future<void> uncheckAll() async {
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
    }

    void _showSnack(String text) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return; // no Scaffold in tree, silently ignore
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }

    return Scaffold(
      // Optional: keep the drawer’s header simple; the parent RightDrawer provides chrome
      appBar: AppBar(
        title: const Text('Personnalisation'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // ---- Top actions (check / uncheck all) ----
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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

              // ---- Quick actions ----
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

              // ---- Nav shortcuts ----
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

              const SizedBox(height: 16),

              // ---- Bottom actions ----
              FilledButton.tonal(
                onPressed: () async {
                  await ctrl.reset();
                  await uiCtrl.reset();
                  _showSnack('Réglages réinitialisés.');
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
      ),
    );
  }
}
