// Linked debt & recent transactions with clickable sums, delete (accounting reversal), and full refresh afterward.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../../../app/account_selection.dart';
import '../providers/customer_linked_providers.dart';
import '../providers/customer_detail_providers.dart';
import '../providers/customer_list_providers.dart';
import '../../transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

// extras for reversal + global refresh
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/app/providers/checkout_cart_usecase_provider.dart'
    hide checkoutCartUseCaseProvider;

import '../customer_debt_payment_panel.dart';
import '../customer_debt_add_panel.dart';

class CustomerLinkedSection extends ConsumerWidget {
  final String customerId;
  const CustomerLinkedSection({super.key, required this.customerId});

  Future<void> _refreshAll(WidgetRef ref) async {
    // Vue actuelle
    ref.invalidate(openDebtByCustomerProvider(customerId));
    ref.invalidate(recentTransactionsOfCustomerProvider(customerId));
    ref.invalidate(customerByIdProvider(customerId));
    // Liste & compteurs
    ref.invalidate(customerListProvider);
    ref.invalidate(customerCountProvider);
    // Transactions & soldes compte
    await ref.read(transactionsProvider.notifier).load();
    await ref.read(balanceProvider.notifier).load();
    ref.invalidate(transactionListItemsProvider);
    ref.invalidate(selectedAccountProvider);
  }

  String _mapReverse(String t) {
    switch (t.toUpperCase()) {
      case 'DEBIT':
        return 'CREDIT';
      case 'CREDIT':
        return 'DEBIT';
      case 'DEBT':
        return 'REMBOURSEMENT';
      case 'REMBOURSEMENT':
        return 'DEBT';
      case 'PRET':
        return 'REMBOURSEMENT';
      default:
        return 'CREDIT';
    }
  }

  Future<bool> _reverseTransaction({
    required BuildContext context,
    required WidgetRef ref,
    required String txId,
  }) async {
    try {
      final db = ref.read(dbProvider);
      final usecase = ref.read(checkoutCartUseCaseProvider);

      // Lecture de la transaction + ses lignes
      final row = await db.tx((txn) async {
        final txRows = await txn.query(
          'transaction_entry',
          where: 'id=?',
          whereArgs: [txId],
          limit: 1,
        );
        if (txRows.isEmpty) return null;
        final items = await txn.query(
          'transaction_item',
          where: 'transactionId=?',
          whereArgs: [txId],
        );
        return {'tx': txRows.first, 'items': items};
      });
      if (row == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Transaction introuvable")),
          );
        }
        return false;
      }

      final tx = row['tx'] as Map<String, Object?>;
      final items = (row['items'] as List).cast<Map<String, Object?>>();
      final type = (tx['typeEntry'] as String?) ?? 'CREDIT';
      final reverseType = _mapReverse(type);

      // Reconstituer les lignes
      final lines = items.isEmpty
          ? <Map<String, Object?>>[
              {
                'productId': null,
                'label': 'Annulation de mouvement',
                'quantity': 1,
                'unitPrice': (tx['amount'] as int?) ?? 0,
              },
            ]
          : items
                .map<Map<String, Object?>>(
                  (it) => {
                    'productId': it['productId'],
                    'label': it['label'] ?? '',
                    'quantity': (it['quantity'] as int?) ?? 1,
                    'unitPrice': (it['unitPrice'] as int?) ?? 0,
                  },
                )
                .toList();

      await usecase.execute(
        typeEntry: reverseType,
        accountId: tx['accountId'] as String?,
        categoryId: tx['categoryId'] as String?,
        description:
            'Annulation ${type.toLowerCase()} • ref ${Formatters.dateFull(DateTime.now())}',
        companyId: tx['companyId'] as String?,
        customerId: tx['customerId'] as String?,
        when: DateTime.now(),
        lines: lines,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec de l’annulation: $e')));
      }
      return false;
    }
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
        // ===== Carte Dette + Sommes cliquables =====
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: debtAsync.when(
              data: (d) {
                // Sommes à partir des transactions récentes visibles
                int sumDebt = 0;
                int sumRepay = 0;
                final txs = txsAsync.asData?.value ?? const [];
                for (final r in txs) {
                  final t = (r.typeEntry ?? '').toUpperCase();
                  if (t == 'DEBT') sumDebt += r.amount;
                  if (t == 'REMBOURSEMENT') sumRepay += r.amount;
                }

                return Column(
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

                    // Sommes cliquables (wrap compact)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.trending_up, size: 18),
                          label: Text(
                            'Somme dettes: ${Formatters.amountFromCents(sumDebt)}',
                          ),
                          onPressed: () async {
                            final ok = await showRightDrawer<bool>(
                              context,
                              child: CustomerDebtAddPanel(
                                customerId: customerId,
                              ),
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
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.trending_down, size: 18),
                          label: Text(
                            'Somme remboursements: ${Formatters.amountFromCents(sumRepay)}',
                          ),
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Boutons principaux (responsive via Wrap)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final ok = await showRightDrawer<bool>(
                              context,
                              child: CustomerDebtAddPanel(
                                customerId: customerId,
                              ),
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
                );
              },
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

        // ===== Transactions récentes (delete via inversion) =====
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
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Aucune transaction'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final typeLabel = switch ((r.typeEntry ?? '')
                            .toUpperCase()) {
                          'DEBIT' => 'Dépense',
                          'CREDIT' => 'Revenu',
                          'DEBT' => 'Dette',
                          'REMBOURSEMENT' => 'Remboursement',
                          'PRET' => 'Prêt',
                          _ => (r.typeEntry ?? '—'),
                        };

                        Future<void> _onDelete() async {
                          final ok = await showRightDrawer<bool>(
                            context,
                            child: _TxDeleteConfirmPanel(
                              title: 'Supprimer (annuler) ?',
                              amountCents: r.amount,
                              description: r.description ?? typeLabel,
                              onConfirm: () async {
                                final done = await _reverseTransaction(
                                  context: context,
                                  ref: ref,
                                  txId: r.id,
                                );
                                return done;
                              },
                            ),
                            widthFraction: 0.86,
                            heightFraction: 0.5,
                          );
                          if (ok == true) {
                            await _refreshAll(ref);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction annulée'),
                                ),
                              );
                            }
                          }
                        }

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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.amountFromCents(r.amount),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                tooltip: 'Menu',
                                onSelected: (v) {
                                  if (v == 'delete') _onDelete();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18),
                                        SizedBox(width: 8),
                                        Text('Supprimer (annuler)'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onLongPress: _onDelete, // raccourci
                        );
                      },
                    );
                  },
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

// ========== Confirm Drawer (inline) ==========
class _TxDeleteConfirmPanel extends StatefulWidget {
  final String title;
  final int amountCents;
  final String description;
  final Future<bool> Function() onConfirm;
  const _TxDeleteConfirmPanel({
    required this.title,
    required this.amountCents,
    required this.description,
    required this.onConfirm,
  });

  @override
  State<_TxDeleteConfirmPanel> createState() => _TxDeleteConfirmPanelState();
}

class _TxDeleteConfirmPanelState extends State<_TxDeleteConfirmPanel> {
  bool _busy = false;

  Future<void> _doConfirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onConfirm();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop<bool>(ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Confirmer l’annulation'),
              subtitle: Text(
                'Cette opération crée une écriture inverse.\n'
                'Montant: ${Formatters.amountFromCents(widget.amountCents)}',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Description'),
              subtitle: Text(widget.description),
            ),
            const Spacer(),
            SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(false),
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _doConfirm,
                      icon: const Icon(Icons.check),
                      label: Text(_busy ? 'Traitement…' : 'Confirmer'),
                    ),
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
