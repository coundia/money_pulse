import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class TransactionTile extends StatelessWidget {
  final TransactionEntry entry;
  final Future<void> Function() onDeleted;
  final Future<void> Function() onUpdated;

  const TransactionTile({
    super.key,
    required this.entry,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = (entry.amount ~/ 100).toString();
    final time = DateFormat.Hm().format(entry.dateTransaction);
    final color = isDebit ? Colors.red : Colors.green;

    return Dismissible(
      key: ValueKey(entry.id),
      background: Container(color: Colors.red),
      onDismissed: (_) async => onDeleted(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(isDebit ? Icons.south : Icons.north, color: color),
        ),
        title: Text(
          entry.description ?? entry.code ?? 'Transaction',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(time),
        trailing: Text(
          '$sign$amount',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        onTap: () async {
          final ok = await showRightDrawer<bool>(
            context,
            child: TransactionFormSheet(entry: entry),
            widthFraction: 0.86,
            heightFraction: 0.96,
          );
          if (ok == true) await onUpdated();
        },
      ),
    );
  }
}
