// Customer details panel: minimalist list UI, responsive, balances are clickable (tap => action menu), full refresh after actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/customer_detail_providers.dart';
import 'providers/customer_list_providers.dart';
import 'widgets/customer_linked_section.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'customer_form_panel.dart';
import 'customer_delete_panel.dart';
import 'widgets/customer_balance_adjust_panel.dart';
import 'customer_debt_add_panel.dart';
import 'customer_debt_payment_panel.dart';

class CustomerViewPanel extends ConsumerWidget {
  final String customerId;
  const CustomerViewPanel({super.key, required this.customerId});

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(customerByIdProvider(customerId));
    ref.invalidate(customerListProvider);
    ref.invalidate(customerCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerByIdProvider(customerId));

    // ===== Actions =====
    Future<void> _onEdit() async {
      final c = await ref.read(customerByIdProvider(customerId).future);
      if (c == null) return;
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerFormPanel(initial: c),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
      if (ok == true) {
        await _refreshAll(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Client mis à jour')));
          Navigator.of(context).pop(true); // ferme la vue si édition validée
        }
      }
    }

    Future<void> _onDelete() async {
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerDeletePanel(customerId: customerId),
        widthFraction: 0.86,
        heightFraction: 0.6,
      );
      if (ok == true && context.mounted) {
        await _refreshAll(ref);
        Navigator.of(context).pop(true);
      }
    }

    Future<void> _onAddBalance() async {
      final c = await ref.read(customerByIdProvider(customerId).future);
      if (c == null) return;
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerBalanceAdjustPanel(
          customerId: c.id,
          currentBalanceCents: c.balance,
          companyId: c.companyId,
          mode: 'add',
        ),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
      if (ok == true) {
        await _refreshAll(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Solde mis à jour')));
        }
      }
    }

    Future<void> _onSetBalance() async {
      final c = await ref.read(customerByIdProvider(customerId).future);
      if (c == null) return;
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerBalanceAdjustPanel(
          customerId: c.id,
          currentBalanceCents: c.balance,
          companyId: c.companyId,
          mode: 'set',
        ),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
      if (ok == true) {
        await _refreshAll(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Solde défini')));
        }
      }
    }

    Future<void> _onDebtAdd() async {
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerDebtAddPanel(customerId: customerId),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
      if (ok == true) {
        await _refreshAll(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dette mise à jour')));
        }
      }
    }

    Future<void> _onDebtPayment() async {
      final ok = await showRightDrawer<bool>(
        context,
        child: CustomerDebtPaymentPanel(customerId: customerId),
        widthFraction: 0.86,
        heightFraction: 0.9,
      );
      if (ok == true) {
        await _refreshAll(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Paiement encaissé')));
        }
      }
    }

    List<PopupMenuEntry<String>> _menuItems() => const [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('Modifier'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18),
            SizedBox(width: 8),
            Text('Supprimer'),
          ],
        ),
      ),
    ];

    Future<void> _handleMenuSelection(String v) async {
      switch (v) {
        case 'edit':
          await _onEdit();
          break;
        case 'delete':
          await _onDelete();
          break;
      }
    }

    // Menu contextuel utilisé par les cartes Solde / Dette
    Future<void> _showCardMenu(
      BuildContext ctx,
      Offset pos, {
      required List<PopupMenuEntry<String>> items,
      required Future<void> Function(String) onSelected,
    }) async {
      final selected = await showMenu<String>(
        context: ctx,
        position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
        items: items,
      );
      if (selected != null) {
        await onSelected(selected);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails client'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (_) => _menuItems(),
          ),
        ],
      ),
      body: async.when(
        data: (c) {
          if (c == null) {
            return const Center(child: Text('Client introuvable'));
          }
          final companyAsync = ref.watch(
            companyOfCustomerProvider(c.companyId),
          );

          // ===== En-tête minimaliste =====
          final header = ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              c.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(
              (c.phone ?? '').isNotEmpty ? c.phone! : (c.email ?? '—'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;
                final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                await _showCardMenu(
                  context,
                  pos.translate(0, 56),
                  items: _menuItems(),
                  onSelected: (v) => _handleMenuSelection(v),
                );
              },
            ),
          );

          // ===== Cards cliquables (Solde / Dette) =====
          Widget _clickableStatCard({
            required String title,
            required String value,
            Color? color,
            required Future<void> Function() onTapDefault, // tap simple
            required List<PopupMenuEntry<String>> contextItems, // menu
            required Future<void> Function(String) onMenuSelected,
          }) {
            Offset tapPosition = Offset.zero;
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTapDown: (d) => tapPosition = d.globalPosition,
                onTap: onTapDefault,
                onLongPress: () async {
                  await _showCardMenu(
                    context,
                    tapPosition,
                    items: contextItems,
                    onSelected: onMenuSelected,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Text(
                                value,
                                key: ValueKey(value),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(color: color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.touch_app, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }

          // Menu Solde (ajout / définir)
          List<PopupMenuEntry<String>> _soldeMenu() => const [
            PopupMenuItem(
              value: 'add',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Ajouter au solde'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'set',
              child: Row(
                children: [
                  Icon(Icons.edit_note_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Définir le solde'),
                ],
              ),
            ),
          ];

          Future<void> _onSoldeMenuSelected(String v) async {
            switch (v) {
              case 'add':
                await _onAddBalance();
                break;
              case 'set':
                await _onSetBalance();
                break;
            }
          }

          // Menu Dette (ajouter / encaisser)
          List<PopupMenuEntry<String>> _detteMenu() => const [
            PopupMenuItem(
              value: 'addDebt',
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_checkout_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Ajouter à la dette'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'payDebt',
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Encaisser un paiement'),
                ],
              ),
            ),
          ];

          Future<void> _onDetteMenuSelected(String v) async {
            switch (v) {
              case 'addDebt':
                await _onDebtAdd();
                break;
              case 'payDebt':
                await _onDebtPayment();
                break;
            }
          }

          final soldeValue = '${Formatters.amountFromCents(c.balance)} CFA';
          final detteValue = '${Formatters.amountFromCents(c.balanceDebt)} CFA';

          // ===== Layout minimal / liste =====
          return RefreshIndicator(
            onRefresh: () => _refreshAll(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                header,
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, cs) {
                    final isWide = cs.maxWidth >= 640;
                    final soldeCard = _clickableStatCard(
                      title: 'Solde',
                      value: soldeValue,
                      onTapDefault: _onAddBalance, // tap rapide => Ajouter
                      contextItems: _soldeMenu(),
                      onMenuSelected: _onSoldeMenuSelected,
                    );
                    final detteCard = _clickableStatCard(
                      title: 'Dette',
                      value: detteValue,
                      color: Theme.of(context).colorScheme.error,
                      onTapDefault:
                          _onDebtAdd, // tap rapide => Ajouter à la dette
                      contextItems: _detteMenu(),
                      onMenuSelected: _onDetteMenuSelected,
                    );
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: soldeCard),
                          const SizedBox(width: 8),
                          Expanded(child: detteCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        soldeCard,
                        const SizedBox(height: 8),
                        detteCard,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Liens (dette + récentes) – déjà rafraîchis via invalidate dans les panneaux
                CustomerLinkedSection(customerId: customerId),

                const Divider(height: 24),

                // Infos minimales
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Téléphone'),
                  subtitle: Text(c.phone ?? '—'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Email'),
                  subtitle: Text(c.email ?? '—'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Statut'),
                  subtitle: Text(c.status ?? '—'),
                ),
                companyAsync.when(
                  data: (co) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Société'),
                    subtitle: Text(co == null ? '—' : (co.name ?? '—')),
                  ),
                  loading: () => const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Société'),
                    subtitle: Text('Chargement...'),
                  ),
                  error: (_, __) => const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Société'),
                    subtitle: Text('Erreur'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}
