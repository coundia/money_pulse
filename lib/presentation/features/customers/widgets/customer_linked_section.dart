// Linked debt & recent transactions for a customer, with post-action refresh & responsive buttons.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../providers/customer_linked_providers.dart';
import '../providers/customer_detail_providers.dart';
import '../providers/customer_list_providers.dart';
import '../../transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../customer_debt_payment_panel.dart';
import '../customer_debt_add_panel.dart';

class CustomerLinkedSection extends ConsumerWidget {
  final String customerId;
  const CustomerLinkedSection({super.key, required this.customerId});

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(openDebtByCustomerProvider(customerId));
    ref.invalidate(recentTransactionsOfCustomerProvider(customerId));
    ref.invalidate(
      customerByIdProvider(customerId),
    ); // met à jour les soldes dans la vue
    ref.invalidate(customerListProvider); // met à jour la liste au retour
    ref.invalidate(customerCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(openDebtByCustomerProvider(customerId));
    final txsAsync = ref.watch(
      recentTransactionsOfCustomerProvider(customerId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte Dette
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: debtAsync.when(
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dette en cours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d == null
                        ? 'Aucune dette active'
                        : Formatters.amountFromCents(d.balance),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final ok = await showRightDrawer<bool>(
                            context,
                            child: CustomerDebtAddPanel(customerId: customerId),
                            widthFraction: 0.86,
                            heightFraction: 0.96,
                          );
                          if (ok == true) {
                            await _refreshAll(ref);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Dette mise à jour'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('Ajouter à la dette'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final ok = await showRightDrawer<bool>(
                            context,
                            child: CustomerDebtPaymentPanel(
                              customerId: customerId,
                            ),
                            widthFraction: 0.86,
                            heightFraction: 0.9,
                          );
                          if (ok == true) {
                            await _refreshAll(ref);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paiement enregistré'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Encaisser un paiement'),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const ListTile(
                title: Text('Dette en cours'),
                subtitle: LinearProgressIndicator(),
              ),
              error: (e, _) => ListTile(
                title: const Text('Dette en cours'),
                subtitle: Text('Erreur: $e'),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Transactions récentes
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transactions récentes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                txsAsync.when(
                  data: (rows) => rows.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Aucune transaction'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final typeLabel = switch (r.typeEntry) {
                              'DEBIT' => 'Dépense',
                              'CREDIT' => 'Revenu',
                              'DEBT' => 'Dette',
                              'REMBOURSEMENT' => 'Remboursement',
                              'PRET' => 'Prêt',
                              _ => r.typeEntry,
                            };
                            return ListTile(
                              dense: true,
                              title: Text(
                                (r.description?.isNotEmpty ?? false)
                                    ? r.description!
                                    : typeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                Formatters.dateFull(r.dateTransaction),
                              ),
                              trailing: Text(
                                Formatters.amountFromCents(r.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          },
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erreur: $e'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await showRightDrawer<bool>(
                        context,
                        child: const TransactionQuickAddSheet(
                          initialIsDebit: true,
                        ),
                        widthFraction: 0.92,
                        heightFraction: 0.98,
                      );
                      if (ok == true) {
                        await _refreshAll(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction ajoutée'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle transaction'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
