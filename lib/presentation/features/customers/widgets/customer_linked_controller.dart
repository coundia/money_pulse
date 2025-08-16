// Controller for customer-linked actions; passes initial customer and default type to quick add.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../../app/account_selection.dart';
import '../customer_debt_add_panel.dart';
import '../customer_debt_payment_panel.dart';
import '../providers/customer_linked_providers.dart';
import '../providers/customer_detail_providers.dart';
import '../providers/customer_list_providers.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/app/providers/checkout_cart_usecase_provider.dart'
    hide checkoutCartUseCaseProvider;

import '../../transactions/transaction_quick_add_sheet.dart';
import 'customer_transactions_popup.dart';

class CustomerLinkedController {
  Future<void> refreshAll(WidgetRef ref, String customerId) async {
    ref.invalidate(openDebtByCustomerProvider(customerId));
    ref.invalidate(recentTransactionsOfCustomerProvider(customerId));
    ref.invalidate(customerByIdProvider(customerId));
    ref.invalidate(customerListProvider);
    ref.invalidate(customerCountProvider);
    await ref.read(transactionsProvider.notifier).load();
    await ref.read(balanceProvider.notifier).load();
    ref.invalidate(transactionListItemsProvider);
    ref.invalidate(selectedAccountProvider);
  }

  Future<void> openAddDebt(
    BuildContext context,
    WidgetRef ref,
    String customerId,
  ) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDebtAddPanel(customerId: customerId),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      await refreshAll(ref, customerId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dette mise à jour')));
      }
    }
  }

  Future<void> openPayment(
    BuildContext context,
    WidgetRef ref,
    String customerId,
  ) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerDebtPaymentPanel(customerId: customerId),
      widthFraction: 0.86,
      heightFraction: 0.9,
    );
    if (ok == true) {
      await refreshAll(ref, customerId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Paiement enregistré')));
      }
    }
  }

  Future<void> openTransactionsPopup(
    BuildContext context,
    WidgetRef ref,
    String customerId,
  ) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: CustomerTransactionsPopup(customerId: customerId),
      widthFraction: 0.92,
      heightFraction: 0.98,
    );
    if (ok == true) {
      await refreshAll(ref, customerId);
    }
  }

  String _mapReverseSimple(String t) {
    switch (t.toUpperCase()) {
      case 'DEBIT':
        return 'CREDIT';
      case 'CREDIT':
        return 'DEBIT';
      case 'DEBT':
        return 'REMBOURSEMENT';
      case 'PRET':
        return 'REMBOURSEMENT';
      default:
        return 'CREDIT';
    }
  }

  Future<bool> reverseTransaction({
    required BuildContext context,
    required WidgetRef ref,
    required String txId,
  }) async {
    try {
      final db = ref.read(dbProvider);
      final usecase = ref.read(checkoutCartUseCaseProvider);

      final row = await db.tx((txn) async {
        final txRows = await txn.query(
          'transaction_entry',
          where: 'id=?',
          whereArgs: [txId],
          limit: 1,
        );
        if (txRows.isEmpty) return null;
        final items = await txn.query(
          'transaction_item',
          where: 'transactionId=?',
          whereArgs: [txId],
        );
        return {'tx': txRows.first, 'items': items};
      });
      if (row == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction introuvable')),
          );
        }
        return false;
      }

      final tx = row['tx'] as Map<String, Object?>;
      final items = (row['items'] as List).cast<Map<String, Object?>>();
      final type = ((tx['typeEntry'] as String?) ?? '').toUpperCase();
      final accountId = tx['accountId'] as String?;
      final companyId = tx['companyId'] as String?;
      final categoryId = tx['categoryId'] as String?;
      final customerIdTx = tx['customerId'] as String?;
      final amount = (tx['amount'] as int?) ?? 0;

      final lines = items.isEmpty
          ? <Map<String, Object?>>[
              {
                'productId': null,
                'label': 'Annulation de mouvement',
                'quantity': 1,
                'unitPrice': amount,
              },
            ]
          : items
                .map<Map<String, Object?>>(
                  (it) => {
                    'productId': it['productId'],
                    'label': it['label'] ?? '',
                    'quantity': (it['quantity'] as int?) ?? 1,
                    'unitPrice': (it['unitPrice'] as int?) ?? 0,
                  },
                )
                .toList();

      final descBase =
          'Annulation ${type.toLowerCase()} • ref ${Formatters.dateFull(DateTime.now())}';

      if (type == 'REMBOURSEMENT') {
        await usecase.execute(
          typeEntry: 'DEBIT',
          accountId: accountId,
          categoryId: categoryId,
          description: '$descBase (sortie caisse)',
          companyId: companyId,
          customerId: customerIdTx,
          when: DateTime.now(),
          lines: lines,
        );
        await usecase.execute(
          typeEntry: 'DEBT',
          accountId: null,
          categoryId: categoryId,
          description: '$descBase (réouverture dette)',
          companyId: companyId,
          customerId: customerIdTx,
          when: DateTime.now(),
          lines: lines,
        );
      } else if (type == 'DEBT') {
        await usecase.execute(
          typeEntry: 'REMBOURSEMENT',
          accountId: accountId,
          categoryId: categoryId,
          description: descBase,
          companyId: companyId,
          customerId: customerIdTx,
          when: DateTime.now(),
          lines: lines,
        );
      } else {
        final reverseType = _mapReverseSimple(type);
        await usecase.execute(
          typeEntry: reverseType,
          accountId: accountId,
          categoryId: categoryId,
          description: descBase,
          companyId: companyId,
          customerId: customerIdTx,
          when: DateTime.now(),
          lines: lines,
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec de l’annulation: $e')));
      }
      return false;
    }
  }

  Future<void> addQuickTransaction(
    BuildContext context,
    WidgetRef ref,
    String customerId,
  ) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: TransactionQuickAddSheet(
        initialCustomerId: customerId,
        initialTypeEntry: 'DEBT',
      ),
      widthFraction: 0.92,
      heightFraction: 0.98,
    );
    if (ok == true) {
      await refreshAll(ref, customerId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction ajoutée')));
      }
    }
  }
}
