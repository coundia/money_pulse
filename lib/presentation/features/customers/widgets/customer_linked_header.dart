// Header card showing current debt, quick sums, and actions; uses controller for flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import '../providers/customer_linked_providers.dart';
import 'customer_linked_controller.dart';

class CustomerLinkedHeader extends ConsumerWidget {
  final String customerId;
  const CustomerLinkedHeader({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = CustomerLinkedController();
    final debtAsync = ref.watch(openDebtByCustomerProvider(customerId));
    final txsAsync = ref.watch(
      recentTransactionsOfCustomerProvider(customerId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dette en cours',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            debtAsync.when(
              data: (d) => Text(
                d == null
                    ? 'Aucune dette active'
                    : Formatters.amountFromCents(d.balance),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
            ),
            const SizedBox(height: 12),
            txsAsync.when(
              data: (rows) {
                var sumDebt = 0;
                var sumRepay = 0;
                for (final r in rows) {
                  final t = (r.typeEntry ?? '').toUpperCase();
                  if (t == 'DEBT') sumDebt += r.amount;
                  if (t == 'REMBOURSEMENT') sumRepay += r.amount;
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.trending_up, size: 18),
                      label: Text(
                        'Somme dettes: ${Formatters.amountFromCents(sumDebt)}',
                      ),
                      onPressed: () =>
                          controller.openAddDebt(context, ref, customerId),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.trending_down, size: 18),
                      label: Text(
                        'Somme remboursements: ${Formatters.amountFromCents(sumRepay)}',
                      ),
                      onPressed: () =>
                          controller.openPayment(context, ref, customerId),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Erreur: $e'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      controller.openAddDebt(context, ref, customerId),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Ajouter à la dette'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      controller.openPayment(context, ref, customerId),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Encaisser un paiement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
