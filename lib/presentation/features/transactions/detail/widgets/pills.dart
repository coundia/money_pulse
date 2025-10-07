// lib/presentation/features/transactions/detail/widgets/pills.dart

import 'package:flutter/material.dart';

class Tone {
  final Color color;
  final IconData icon;
  final String label;
  const Tone({required this.color, required this.icon, required this.label});
}

Tone toneForType(BuildContext context, String type) {
  final scheme = Theme.of(context).colorScheme;
  switch (type.toUpperCase()) {
    case 'DEBIT':
      return Tone(color: scheme.error, icon: Icons.south, label: 'Dépense');
    case 'CREDIT':
      return Tone(color: scheme.tertiary, icon: Icons.north, label: 'Revenu');
    case 'REMBOURSEMENT':
      return const Tone(
        color: Colors.teal,
        icon: Icons.undo_rounded,
        label: 'Remboursement',
      );
    case 'PRET':
      return const Tone(
        color: Colors.purple,
        icon: Icons.account_balance_outlined,
        label: 'Prêt',
      );
    case 'DEBT':
      return Tone(
        color: Colors.amber.shade800,
        icon: Icons.receipt_long,
        label: 'Dette',
      );
    default:
      return Tone(
        color: scheme.primary,
        icon: Icons.receipt_long,
        label: type.toUpperCase(),
      );
  }
}

class TypePill extends StatelessWidget {
  final String label;
  final Color color;
  const TypePill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    final fg = color.withOpacity(0.95);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class TypePillSmall extends StatelessWidget {
  final String label;
  final Color color;
  const TypePillSmall({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.10);
    final fg = color.withOpacity(0.90);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.28), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String? status;
  final Tone tone;

  const StatusPill({super.key, required this.status, required this.tone});

  @override
  Widget build(BuildContext context) {
    final s = (status ?? '').trim();
    if (s.isEmpty) return const SizedBox.shrink();

    String label;
    Color color;
    switch (s.toUpperCase()) {
      case 'DEBT':
        label = 'Dette';
        color = Colors.amber.shade800;
        break;
      case 'REPAYMENT':
        label = 'Remboursement';
        color = Colors.teal;
        break;
      case 'LOAN':
        label = 'Prêt';
        color = Colors.purple;
        break;
      default:
        label = s;
        color = tone.color;
    }
    return TypePillSmall(label: label, color: color);
  }
}
