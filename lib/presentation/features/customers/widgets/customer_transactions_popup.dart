// Popup (right drawer) listing recent customer transactions with reverse-delete action and live refresh.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../providers/customer_linked_providers.dart';
import 'customer_linked_controller.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class CustomerTransactionsPopup extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerTransactionsPopup({super.key, required this.customerId});

  @override
  ConsumerState<CustomerTransactionsPopup> createState() =>
      _CustomerTransactionsPopupState();
}

class _CustomerTransactionsPopupState
    extends ConsumerState<CustomerTransactionsPopup> {
  bool _dirty = false;

  String _typeLabel(String? t) {
    switch ((t ?? '').toUpperCase()) {
      case 'DEBIT':
        return 'Dépense';
      case 'CREDIT':
        return 'Revenu';
      case 'DEBT':
        return 'Dette';
      case 'REMBOURSEMENT':
        return 'Remboursement';
      case 'PRET':
        return 'Prêt';
      default:
        return t ?? '—';
    }
  }

  Future<void> _reverseOne(
    BuildContext context,
    String txId,
    String title,
    int amount,
  ) async {
    final controller = CustomerLinkedController();
    final ok = await showRightDrawer<bool>(
      context,
      child: _TxReverseConfirmPanel(
        title: title,
        amountCents: amount,
        onConfirm: () async {
          final done = await controller.reverseTransaction(
            context: context,
            ref: ref,
            txId: txId,
          );
          if (done) {
            await controller.refreshAll(ref, widget.customerId);
            setState(() => _dirty = true);
          }
          return done;
        },
      ),
      widthFraction: 0.86,
      heightFraction: 0.5,
    );
    if (ok == true) {
      await controller.refreshAll(ref, widget.customerId);
      setState(() => _dirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(
      recentTransactionsOfCustomerProvider(widget.customerId),
    );
    final controller = CustomerLinkedController();

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop<bool>(_dirty);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transactions du client'),
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(_dirty),
          ),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await controller.refreshAll(ref, widget.customerId);
                setState(() {});
              },
            ),
          ],
        ),
        body: txsAsync.when(
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('Aucune transaction'));
            }
            return ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                final label = (r.description?.isNotEmpty ?? false)
                    ? r.description!
                    : _typeLabel(r.typeEntry);
                return ListTile(
                  dense: true,
                  title: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(Formatters.dateFull(r.dateTransaction)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.amountFromCents(r.amount),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'delete') {
                            _reverseOne(
                              context,
                              r.id,
                              'Supprimer (annuler) ?',
                              r.amount,
                            );
                          }
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
                  onLongPress: () => _reverseOne(
                    context,
                    r.id,
                    'Supprimer (annuler) ?',
                    r.amount,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => controller.addQuickTransaction(
                  context,
                  ref,
                  widget.customerId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle transaction'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TxReverseConfirmPanel extends StatefulWidget {
  final String title;
  final int amountCents;
  final Future<bool> Function() onConfirm;
  const _TxReverseConfirmPanel({
    required this.title,
    required this.amountCents,
    required this.onConfirm,
  });

  @override
  State<_TxReverseConfirmPanel> createState() => _TxReverseConfirmPanelState();
}

class _TxReverseConfirmPanelState extends State<_TxReverseConfirmPanel> {
  bool _busy = false;

  Future<void> _confirm() async {
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
                'Montant: ${Formatters.amountFromCents(widget.amountCents)}',
              ),
            ),
            const Spacer(),
            Row(
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
                    onPressed: _busy ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: Text(_busy ? 'Traitement…' : 'Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
