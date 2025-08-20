// App bar title for Home: shows current balance and optional goal/limit chips with safe horizontal scroll (FR labels, EN code).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';

import 'goal_limit_chip.dart';

class HomeAppBarTitle extends StatelessWidget {
  final AsyncValue<Account?> accountAsync;
  final VoidCallback onTap;

  const HomeAppBarTitle({
    super.key,
    required this.accountAsync,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: accountAsync.when(
        loading: () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              amountCents: 0,
              currency: 'XOF',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            const Text('…', style: TextStyle(fontSize: 12)),
          ],
        ),
        error: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              amountCents: 0,
              currency: 'XOF',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            const Text('Compte', style: TextStyle(fontSize: 12)),
          ],
        ),
        data: (acc) {
          final currency = acc?.currency ?? 'XOF';
          final goal = (acc?.balanceGoal ?? 0);
          final limit = (acc?.balanceLimit ?? 0);
          final hasGoal = goal > 0;
          final hasLimit = limit > 0;

          // Prefer a human label, avoid showing IDs.
          final label = (acc?.description?.trim().isNotEmpty ?? false)
              ? acc!.description!.trim()
              : 'Compte';

          final cs = Theme.of(context).colorScheme;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyText(
                amountCents: acc?.balance ?? 0,
                currency: currency,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more, size: 16),
                      ],
                    ),
                    if (hasGoal || hasLimit) const SizedBox(width: 8),
                    if (hasGoal || hasLimit)
                      Wrap(
                        spacing: 6,
                        children: [
                          if (hasGoal)
                            GoalLimitChip(
                              kind: GoalLimitChipKind.goal,
                              amountCents: goal,
                              currency: currency,
                              label: 'Objectif',
                              icon: Icons.flag_outlined,
                            ),
                          if (hasLimit)
                            GoalLimitChip(
                              kind: GoalLimitChipKind.limit,
                              amountCents: limit,
                              currency: currency,
                              label: 'Plafond',
                              icon: Icons.speed_rounded,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
