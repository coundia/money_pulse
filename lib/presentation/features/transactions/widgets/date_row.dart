import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class DateRow extends StatelessWidget {
  final DateTime when;
  final VoidCallback onPick;
  const DateRow({super.key, required this.when, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Date'),
      subtitle: Text(Formatters.dateFull(when)),
      trailing: const Icon(Icons.calendar_today),
      onTap: onPick,
    );
  }
}
