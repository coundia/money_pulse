// App bar title with animated balance and goal/limit chips that signal reached/exceeded states (FR labels, EN code).
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

    Widget _loading() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(amountCents: 0, currency: 'XOF', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        const Text('…', style: TextStyle(fontSize: 12)),
      ],
    );

    Widget _error() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(amountCents: 0, currency: 'XOF', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        const Text('Compte', style: TextStyle(fontSize: 12)),
      ],
    );

    return Tooltip(
      message: 'Changer de compte',
      child: Semantics(
        button: true,
        label: 'En-tête du compte: appuyer pour changer',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: accountAsync.when(
            loading: _loading,
            error: (_, __) => _error(),
            data: (acc) {
              final currency = acc?.currency ?? 'XOF';
              final balance = acc?.balance ?? 0;
              final goal = (acc?.balanceGoal ?? 0);
              final limit = (acc?.balanceLimit ?? 0);
              final hasGoal = goal > 0;
              final hasLimit = limit > 0;

              // Status computation
              final GoalLimitStatus goalStatus = hasGoal
                  ? (balance >= goal
                        ? GoalLimitStatus.reached
                        : GoalLimitStatus.normal)
                  : GoalLimitStatus.normal;

              final GoalLimitStatus limitStatus = hasLimit
                  ? (balance > limit
                        ? GoalLimitStatus.exceeded
                        : (balance == limit
                              ? GoalLimitStatus.reached
                              : GoalLimitStatus.normal))
                  : GoalLimitStatus.normal;

              final label = (acc?.description?.trim().isNotEmpty ?? false)
                  ? acc!.description!.trim()
                  : 'Compte';

              final chips = [
                if (hasGoal)
                  GoalLimitChip(
                    kind: GoalLimitChipKind.goal,
                    status: goalStatus,
                    amountCents: goal,
                    currency: currency,
                    label: 'Objectif',
                    icon: Icons.flag_outlined,
                  ),
                if (hasLimit)
                  GoalLimitChip(
                    kind: GoalLimitChipKind.limit,
                    status: limitStatus,
                    amountCents: limit,
                    currency: currency,
                    label: 'Plafond',
                    icon: Icons.speed_rounded,
                  ),
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 320;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: MoneyText(
                          key: ValueKey('$balance-$currency'),
                          amountCents: balance,
                          currency: currency,
                          style: textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isTight)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            if ((hasGoal || hasLimit) && !isTight)
                              const SizedBox(width: 8),
                            if (hasGoal || hasLimit)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Row(
                                  key: ValueKey(
                                    '${hasGoal}_${hasLimit}_ $goal $limit _${goalStatus.name}_${limitStatus.name}',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isTight)
                                      const Icon(Icons.expand_more, size: 16),
                                    if (chips.isNotEmpty)
                                      Wrap(spacing: 6, children: chips),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
