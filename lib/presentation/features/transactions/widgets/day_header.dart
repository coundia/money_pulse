import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/transaction_grouping.dart';

class DayHeader extends StatelessWidget {
  final DayGroup group;
  const DayHeader({super.key, required this.group});

  String _friendly(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == yesterday) return 'Yesterday';
    return DateFormat.EEEE().addPattern(', ').add_MMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final net = group.net;
    final netColor = net >= 0 ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Text(
            _friendly(group.day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Text(
            '${net >= 0 ? '+' : ''}${net ~/ 100}',
            style: TextStyle(color: netColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
