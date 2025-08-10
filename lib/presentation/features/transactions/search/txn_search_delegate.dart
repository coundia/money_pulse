import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

class TxnSearchDelegate extends SearchDelegate<TransactionEntry?> {
  final List<TransactionEntry> items;
  TxnSearchDelegate(this.items);

  List<TransactionEntry> _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((e) {
      final text = '${e.code ?? ''} ${e.description ?? ''}'.toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final filtered = _filter(query);
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = filtered[i];
        final isDebit = e.typeEntry == 'DEBIT';
        final color = isDebit ? Colors.red : Colors.green;
        final sign = isDebit ? '-' : '+';
        return ListTile(
          title: Text(
            e.description ?? e.code ?? 'Transaction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(DateFormat.yMMMd().add_Hm().format(e.dateTransaction)),
          trailing: Text(
            '$sign${e.amount ~/ 100}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onTap: () => close(context, e),
        );
      },
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
}
