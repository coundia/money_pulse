import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionsProvider);
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) {
        final e = items[i];
        final isDebit = e.typeEntry == 'DEBIT';
        final sign = isDebit ? '-' : '+';
        final amount = (e.amount ~/ 100).toString();
        final date = DateFormat.yMMMd().format(e.dateTransaction);
        final color = isDebit ? Colors.red : Colors.green;
        return Dismissible(
          key: ValueKey(e.id),
          background: Container(color: Colors.red),
          onDismissed: (_) async {
            await ref.read(transactionRepoProvider).softDelete(e.id);
            await ref.read(balanceProvider.notifier).load();
            await ref.read(transactionsProvider.notifier).load();
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(isDebit ? Icons.south : Icons.north, color: color),
            ),
            title: Text(e.description ?? e.code ?? 'Transaction'),
            subtitle: Text(date),
            trailing: Text(
              '$sign$amount',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            onTap: () async {
              final ok = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TransactionFormSheet(entry: e),
              );
              if (ok == true) {
                await ref.read(balanceProvider.notifier).load();
                await ref.read(transactionsProvider.notifier).load();
              }
            },
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }
}
