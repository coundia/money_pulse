// App bar title with richer info: animated balance, delta vs previous, type chip, goal/limit chips, remaining pills, last update; all horizontally scrollable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'goal_limit_chip.dart';

class HomeAppBarTitle extends StatelessWidget {
  final AsyncValue<Account?> accountAsync;
  final VoidCallback onTap;

  const HomeAppBarTitle({
    super.key,
    required this.accountAsync,
    required this.onTap,
  });

  static const Map<String, String> _typeFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget max',
    'OTHER': 'Autre',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget loading() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(amountCents: 0, currency: 'XOF', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        const Text('…', style: TextStyle(fontSize: 12)),
      ],
    );

    Widget error() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyText(amountCents: 0, currency: 'XOF', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        const Text('Compte', style: TextStyle(fontSize: 12)),
      ],
    );

    Widget remainBadge({
      required IconData icon,
      required String text,
      required Color bg,
      required Color fg,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget typeChip(BuildContext context, String? typeKey) {
      final cs = Theme.of(context).colorScheme;
      final label = _typeFr[typeKey] ?? _typeFr['OTHER']!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget deltaBadge(BuildContext context, int deltaCents, String currency) {
      final cs = Theme.of(context).colorScheme;
      final up = deltaCents > 0;
      final eq = deltaCents == 0;
      final fg = eq
          ? cs.onSurfaceVariant
          : (up ? cs.onTertiaryContainer : cs.onErrorContainer);
      final bg = eq
          ? cs.surfaceVariant.withOpacity(.6)
          : (up ? cs.tertiaryContainer : cs.errorContainer);
      final icon = eq
          ? Icons.horizontal_rule_rounded
          : (up ? Icons.trending_up : Icons.trending_down);
      final txt = eq ? 'Égal' : Formatters.amountFromCents(deltaCents.abs());
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              '$txt ${currency.isEmpty ? '' : currency}'.trim(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Tooltip(
      message: 'Changer de compte',
      child: Semantics(
        button: true,
        label: 'En-tête du compte: appuyer pour changer',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: accountAsync.when(
            loading: loading,
            error: (_, __) => error(),
            data: (acc) {
              final cs = Theme.of(context).colorScheme;

              final currency = acc?.currency ?? 'XOF';
              final balance = acc?.balance ?? 0;
              final balancePrev = acc?.balancePrev ?? 0;
              final delta = balance - balancePrev;

              final goal = acc?.balanceGoal ?? 0;
              final limit = acc?.balanceLimit ?? 0;
              final hasGoal = goal > 0;
              final hasLimit = limit > 0;

              final goalStatus = hasGoal
                  ? (balance >= goal
                        ? GoalLimitStatus.reached
                        : GoalLimitStatus.normal)
                  : GoalLimitStatus.normal;

              final limitStatus = hasLimit
                  ? (balance > limit
                        ? GoalLimitStatus.exceeded
                        : (balance == limit
                              ? GoalLimitStatus.reached
                              : GoalLimitStatus.normal))
                  : GoalLimitStatus.normal;

              final goalRemain = hasGoal ? goal - balance : 0;
              final limitRemain = hasLimit ? limit - balance : 0;

              final label = (acc?.description?.trim().isNotEmpty ?? false)
                  ? acc!.description!.trim()
                  : 'Compte';
              final lastUpdate = acc?.updatedAt;

              final chips = <Widget>[
                typeChip(context, acc?.typeAccount),
                if (hasGoal)
                  GoalLimitChip(
                    kind: GoalLimitChipKind.goal,
                    status: goalStatus,
                    amountCents: goal,
                    currency: currency,
                    label: 'Obj.',
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

              List<Widget> remainPills(bool tight) {
                final pills = <Widget>[];
                if (hasGoal) {
                  if (goalRemain > 0) {
                    pills.add(
                      remainBadge(
                        icon: Icons.flag,
                        text: tight
                            ? '- ${Formatters.amountFromCents(goalRemain)}'
                            : '- ${Formatters.amountFromCents(goalRemain)}',
                        bg: cs.tertiaryContainer,
                        fg: cs.onTertiaryContainer,
                      ),
                    );
                  } else {
                    pills.add(
                      remainBadge(
                        icon: Icons.check_circle,
                        text: 'Atteint',
                        bg: cs.tertiaryContainer.withOpacity(.55),
                        fg: cs.onTertiaryContainer,
                      ),
                    );
                  }
                }
                if (hasLimit) {
                  if (limitRemain >= 0) {
                    pills.add(
                      remainBadge(
                        icon: Icons.stacked_bar_chart,
                        text: tight
                            ? '${Formatters.amountFromCents(limitRemain)} restants'
                            : 'Capacité: ${Formatters.amountFromCents(limitRemain)}',
                        bg: cs.primaryContainer,
                        fg: cs.onPrimaryContainer,
                      ),
                    );
                  } else {
                    pills.add(
                      remainBadge(
                        icon: Icons.warning_amber_rounded,
                        text: tight
                            ? '+ ${Formatters.amountFromCents((-limitRemain))}'
                            : '+ ${Formatters.amountFromCents((-limitRemain))}',
                        bg: cs.errorContainer,
                        fg: cs.onErrorContainer,
                      ),
                    );
                  }
                }
                return pills;
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 360;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Row(
                          key: ValueKey('$balance-$currency-$delta'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MoneyText(
                              amountCents: balance,
                              currency: currency,
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(width: 6),
                            if (!isTight) deltaBadge(context, delta, currency),
                          ],
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
                                  const SizedBox(width: 6),
                                  const Icon(Icons.expand_more, size: 16),
                                ],
                              ),
                            if ((hasGoal ||
                                    hasLimit ||
                                    (acc?.typeAccount != null)) &&
                                !isTight)
                              const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Row(
                                key: ValueKey(
                                  '${acc?.typeAccount}_${hasGoal}_ $goal _${hasLimit}_$limit',
                                ),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isTight)
                                    const Icon(Icons.expand_more, size: 16),
                                  if (chips.isNotEmpty)
                                    Wrap(spacing: 6, children: chips),
                                  if (chips.isNotEmpty)
                                    const SizedBox(width: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: remainPills(isTight),
                                  ),
                                  if (!isTight && lastUpdate != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Maj ${Formatters.timeHm(lastUpdate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
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
