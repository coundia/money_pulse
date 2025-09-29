// lib/presentation/features/customers/widgets/customer_tile.dart
//
// Customer tile with long-press contextual menu to run all actions,
// includes link to CustomerTransactionsPopup, debt/pay actions,
// quick "reset debt to 0" and "reset balance to 0" WITH confirmations.
// + Remote sync actions: "Synchroniser au serveur" and "Supprimer distant + local"
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../../../app/account_selection.dart';
import '../customer_view_panel.dart';
import '../customer_edit_panel.dart';
import '../customer_form_panel.dart';
import '../customer_delete_panel.dart';
import 'customer_balance_adjust_panel.dart';
import 'customer_transactions_popup.dart';
import '../customer_debt_add_panel.dart';
import '../customer_debt_payment_panel.dart';

import '../providers/customer_list_providers.dart';
import '../providers/customer_detail_providers.dart';

// Quick "reset" actions (needs a selected account + use case)
import 'package:money_pulse/presentation/app/providers.dart'
    show selectedAccountIdProvider;
import 'package:money_pulse/presentation/app/providers/checkout_cart_usecase_provider.dart'
    show checkoutCartUseCaseProvider;

// NEW: Marketplace repo for remote sync
import '../customer_marketplace_repo.dart';

class CustomerTile extends ConsumerWidget {
  final Customer customer;
  const CustomerTile({super.key, required this.customer});

  // ---------- Reusable confirmation ----------
  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    IconData icon = Icons.help_outline,
  }) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).maybePop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).maybePop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ---------- Navigation helpers ----------
  Future<void> _openView(BuildContext context, WidgetRef ref) async {
    final changed = await showRightDrawer<bool>(
      context,
      child: CustomerViewPanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (changed == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerEditPanel(initial: customer),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client mis à jour')));
    }
  }

  Future<void> _openAdjustBalance(
    BuildContext context,
    WidgetRef ref, {
    required bool setMode,
  }) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerBalanceAdjustPanel(
        customerId: customer.id,
        currentBalanceCents: customer.balance,
        companyId: customer.companyId,
        mode: setMode ? 'set' : 'add',
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
    }
  }

  Future<void> _openTransactions(BuildContext context, WidgetRef ref) async {
    final dirty = await showRightDrawer<bool>(
      context,
      child: CustomerTransactionsPopup(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (dirty == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
    }
  }

  Future<void> _openAddDebt(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDebtAddPanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dette mise à jour')));
    }
  }

  Future<void> _openAddPayment(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDebtPaymentPanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.9,
    );
    if (ok == true) {
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paiement encaissé')));
    }
  }

  Future<void> _openDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDeletePanel(customerId: customer.id),
      widthFraction: 0.86,
      heightFraction: 0.6,
    );
    if (ok == true) {
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client supprimé')));
    }
  }

  // ---------- Quick actions (with confirmations) ----------
  Future<void> _resetBalanceToZeroQuick(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = customer.balance;
    if (current == 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solde déjà à 0')));
      return;
    }

    // Confirm
    final ok = await _confirmAction(
      context,
      title: 'Réinitialiser le solde à 0',
      message:
          'Solde actuel: ${Formatters.amountFromCents(current)}.\n\nCette action créera une transaction pour ramener le solde à 0. Continuer ?',
      confirmLabel: 'Réinitialiser',
      icon: Icons.account_balance_wallet_outlined,
    );
    if (!ok) return;

    final selectedAccountId = ref.read(selectedAccountIdProvider);
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez d’abord un compte')),
      );
      return;
    }

    final usecase = ref.read(checkoutCartUseCaseProvider);
    // Set to 0: delta = 0 - current
    final delta = -current;
    final typeEntry = delta > 0 ? 'CREDIT' : 'DEBIT';
    final amount = delta.abs();

    try {
      await usecase.execute(
        typeEntry: typeEntry,
        accountId: selectedAccountId,
        companyId: customer.companyId,
        customerId: customer.id,
        description: 'Réinitialisation solde à 0',
        when: DateTime.now(),
        lines: [
          {
            'productId': null,
            'label': 'Reset solde',
            'quantity': 1,
            'unitPrice': amount,
          },
        ],
      );
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solde réinitialisé à 0')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _reimburseAllDebtQuick(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final debt = customer.balanceDebt;
    if (debt <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune dette à rembourser')),
      );
      return;
    }

    // Confirm
    final ok = await _confirmAction(
      context,
      title: 'Rembourser toute la dette',
      message:
          'Montant de la dette: ${Formatters.amountFromCents(debt)}.\n\nUn remboursement de ce montant sera enregistré. Continuer ?',
      confirmLabel: 'Rembourser',
      icon: Icons.payments_outlined,
    );
    if (!ok) return;

    final selectedAccountId = ref.read(selectedAccountIdProvider);
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez d’abord un compte')),
      );
      return;
    }

    final usecase = ref.read(checkoutCartUseCaseProvider);
    try {
      await usecase.execute(
        typeEntry: 'REMBOURSEMENT',
        accountId: selectedAccountId,
        companyId: customer.companyId,
        customerId: customer.id,
        description: 'Remboursement total dette',
        when: DateTime.now(),
        lines: [
          {
            'productId': null,
            'label': 'Remboursement dette',
            'quantity': 1,
            'unitPrice': debt,
          },
        ],
      );
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dette remboursée intégralement')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  // ---------- Remote sync quick actions ----------
  Future<void> _syncRemote(BuildContext context, WidgetRef ref) async {
    try {
      final market = ref.read(
        customerMarketplaceRepoProvider('http://127.0.0.1:8095'),
      );
      await market.saveAndReconcile(customer);
      ref.invalidate(customerByIdProvider(customer.id));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client synchronisé au serveur')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de synchro: $e')));
    }
  }

  Future<void> _deleteRemoteLocal(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer distant + local ?'),
        content: Text(
          'Supprimer « ${customer.fullName} » à distance (si possible) puis localement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final market = ref.read(
        customerMarketplaceRepoProvider('http://127.0.0.1:8095'),
      );
      await market.deleteRemoteThenLocal(customer);
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client supprimé')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de suppression: $e')));
    }
  }

  // ---------- Context menu ----------
  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset globalPos,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        overlay.size.width - globalPos.dx,
        overlay.size.height - globalPos.dy,
      ),
      items: const [
        PopupMenuItem(value: 'view', child: Text('Voir')),
        PopupMenuItem(value: 'transactions', child: Text('Transactions')),
        PopupMenuItem(value: 'add_debt', child: Text('Ajouter à la dette')),
        PopupMenuItem(
          value: 'add_payment',
          child: Text('Encaisser un paiement'),
        ),
        PopupMenuItem(
          value: 'reset_debt',
          child: Text('Rembourser toute la dette'),
        ),
        PopupMenuItem(value: 'add_balance', child: Text('Ajouter au solde')),
        PopupMenuItem(value: 'set_balance', child: Text('Définir le solde')),
        PopupMenuItem(
          value: 'reset_balance',
          child: Text('Réinitialiser le solde à 0'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'sync_remote',
          child: Text('Synchroniser au serveur'),
        ),
        PopupMenuItem(
          value: 'delete_remote_local',
          child: Text('Supprimer distant + local'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(value: 'edit', child: Text('Modifier')),
        PopupMenuItem(value: 'delete', child: Text('Supprimer (local)')),
      ],
    );

    switch (selected) {
      case 'view':
        await _openView(context, ref);
        break;
      case 'transactions':
        await _openTransactions(context, ref);
        break;
      case 'add_debt':
        await _openAddDebt(context, ref);
        break;
      case 'add_payment':
        await _openAddPayment(context, ref);
        break;
      case 'reset_debt':
        await _reimburseAllDebtQuick(context, ref);
        break;
      case 'add_balance':
        await _openAdjustBalance(context, ref, setMode: false);
        break;
      case 'set_balance':
        await _openAdjustBalance(context, ref, setMode: true);
        break;
      case 'reset_balance':
        await _resetBalanceToZeroQuick(context, ref);
        break;
      case 'sync_remote':
        await _syncRemote(context, ref);
        break;
      case 'delete_remote_local':
        await _deleteRemoteLocal(context, ref);
        break;
      case 'edit':
        await _openEdit(context, ref);
        break;
      case 'delete':
        await _openDelete(context, ref);
        break;
      default:
        break;
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: ListTile(
        onTap: () => _openView(context, ref),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(
          customer.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          (customer.phone ?? '').isNotEmpty
              ? customer.phone!
              : (customer.email ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Solde: ${Formatters.amountFromCents(customer.balance)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Dette: ${Formatters.amountFromCents(customer.balanceDebt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
