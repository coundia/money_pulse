// Reusable list tile for an account with concise info.

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

  @override
  Widget build(BuildContext context) {
    final title = account.description?.isNotEmpty == true
        ? account.description!
        : (account.code ?? 'Compte');
    final subtitleParts = <String>[];
    if (account.typeAccount != null && account.typeAccount!.isNotEmpty) {
      subtitleParts.add(account.typeAccount!);
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
