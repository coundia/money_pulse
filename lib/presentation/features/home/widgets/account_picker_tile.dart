// One account row for the picker; uses AccountAvatar and MiniChip, with adjust menu.
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../accounts/widgets/account_avatar.dart';
import '../../accounts/widgets/mini_chip.dart';

class AccountPickerTile extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final VoidCallback onPick;
  final VoidCallback onAdjust;

  const AccountPickerTile({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onPick,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasGoal = (account.balanceGoal) > 0;
    final hasLimit = (account.balanceLimit) > 0;

    return InkWell(
      onTap: onPick,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer.withOpacity(.28) : null,
          border: Border.all(
            color: isSelected ? cs.primary.withOpacity(.55) : cs.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            AccountAvatar(
              type: account.typeAccount,
              isDefault: account.isDefault == 1,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.code ?? 'Compte',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: MoneyText(
                            key: ValueKey(account.balance),
                            amountCents: account.balance,
                            currency: account.currency ?? 'XOF',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.dateShort(account.updatedAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  if (hasGoal || hasLimit) ...[
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (hasGoal)
                            MiniChip.goal(
                              amountCents: account.balanceGoal,
                              currency: account.currency,
                            ),
                          if (hasLimit)
                            MiniChip.limit(
                              amountCents: account.balanceLimit,
                              currency: account.currency,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) Icon(Icons.check, color: cs.primary),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (value) async {
                    if (value == 'adjust') onAdjust();
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'adjust',
                      child: ListTile(
                        leading: Icon(Icons.toll_outlined),
                        title: Text('Ajuster le solde'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
