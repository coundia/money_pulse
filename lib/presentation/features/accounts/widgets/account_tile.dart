import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final bool isDefault;
  final String balanceText;
  final String updatedAtText;
  final VoidCallback onView;
  final VoidCallback? onMakeDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AccountTile({
    super.key,
    required this.account,
    required this.isDefault,
    required this.balanceText,
    required this.updatedAtText,
    required this.onView,
    this.onMakeDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final code = (account.code ?? '').trim();
    final two = code.isEmpty
        ? '?'
        : (code.length >= 2 ? code.substring(0, 2) : code).toUpperCase();
    final sub = account.description?.trim().isNotEmpty == true
        ? account.description!.trim()
        : (account.currency ?? '-');

    return InkWell(
      onTap: onView,
      onLongPress: onMakeDefault,
      child: ListTile(
        leading: CircleAvatar(child: Text(two)),
        title: Row(
          children: [
            Expanded(child: Text(account.code ?? 'NA')),
            if (isDefault)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(sub),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balanceText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(updatedAtText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        selected: isDefault,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.06),
        onLongPress: onMakeDefault,
        onTap: onView,
        dense: false,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}
