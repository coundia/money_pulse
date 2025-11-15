import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jaayko/domain/transactions/entities/transaction_entry.dart';

class TransactionViewSheet extends StatelessWidget {
  final TransactionEntry entry;

  const TransactionViewSheet({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = NumberFormat.decimalPattern(
      'fr_FR',
    ).format(entry.amount / 100);
    final dateLabel = DateFormat.yMMMMEEEEd(
      'fr_FR',
    ).add_Hm().format(entry.dateTransaction);

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de la transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Description'),
            subtitle: Text(entry.description ?? '—'),
          ),
          ListTile(
            title: const Text('Montant'),
            subtitle: Text('$sign$amount'),
          ),
          ListTile(
            title: const Text('Type'),
            subtitle: Text(isDebit ? 'Dépense' : 'Revenu'),
          ),
          ListTile(title: const Text('Date'), subtitle: Text(dateLabel)),
          ListTile(
            title: const Text('Code'),
            subtitle: Text(entry.code ?? '—'),
          ),
          ListTile(title: const Text('Identifiant'), subtitle: Text(entry.id)),
        ],
      ),
    );
  }
}
