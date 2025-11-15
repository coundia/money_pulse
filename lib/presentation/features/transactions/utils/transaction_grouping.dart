import 'package:jaayko/domain/transactions/entities/transaction_entry.dart';

class DayGroup {
  final DateTime day;
  final List<TransactionEntry> items;
  final int expense;
  final int income;

  const DayGroup({
    required this.day,
    required this.items,
    required this.expense,
    required this.income,
  });

  int get net => income - expense;
}

List<DayGroup> groupByDay(List<TransactionEntry> items) {
  final map = <DateTime, List<TransactionEntry>>{};
  for (final e in items) {
    final d = DateTime(
      e.dateTransaction.year,
      e.dateTransaction.month,
      e.dateTransaction.day,
    );
    map.putIfAbsent(d, () => []).add(e);
  }
  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return days.map((d) {
    final dayItems = map[d]!
      ..sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
    final expense = dayItems
        .where((e) => e.typeEntry == 'DEBIT')
        .fold<int>(0, (p, e) => p + e.amount);
    final income = dayItems
        .where((e) => e.typeEntry == 'CREDIT')
        .fold<int>(0, (p, e) => p + e.amount);
    return DayGroup(day: d, items: dayItems, expense: expense, income: income);
  }).toList();
}
