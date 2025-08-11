import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class ReportAccountHeader extends StatelessWidget {
  final Account account;
  const ReportAccountHeader({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final raw = (account.code ?? '—').trim();
    final badge = raw.isEmpty
        ? '—'
        : raw.characters.take(2).toString().toUpperCase();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            CircleAvatar(radius: 16, child: Text(badge)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        'Solde : ${Formatters.amountFromCents(account.balance)} ${account.currency ?? 'XOF'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
