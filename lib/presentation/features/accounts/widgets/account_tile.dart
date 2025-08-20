// Reusable list tile for an account with localized type label and concise info.

import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final String balanceText;
  final String updatedAtText;
  final VoidCallback? onView;
  const AccountTile({
    super.key,
    required this.account,
    required this.balanceText,
    required this.updatedAtText,
    this.onView,
  });

  static const _typeLabelsFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget maximum',
    'OTHER': 'Autre',
  };

  @override
  Widget build(BuildContext context) {
    final title = account.description?.isNotEmpty == true
        ? account.description!
        : (account.code ?? 'Compte');
    final subtitleParts = <String>[];
    final typeFr =
        _typeLabelsFr[account.typeAccount] ?? (account.typeAccount ?? '');
    if (typeFr.isNotEmpty) {
      subtitleParts.add(typeFr);
    }
    subtitleParts.add(updatedAtText);
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Text(
        balanceText,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: onView,
    );
  }
}
