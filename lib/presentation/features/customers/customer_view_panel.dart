// Customer details panel with compact UI and actions accessible from app bar menu, refreshing providers after actions.
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

    Future<void> onEdit() async {
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
        if (context.mounted) Navigator.of(context).pop(true);
      }
    }

    Future<void> onAddBalance() async {
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
        if (context.mounted) Navigator.of(context).pop(true);
      }
    }

    Future<void> onSetBalance() async {
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
        if (context.mounted) Navigator.of(context).pop(true);
      }
    }

    Future<void> onDelete() async {
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
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit();
                  break;
                case 'add_balance':
                  onAddBalance();
                  break;
                case 'set_balance':
                  onSetBalance();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (_) => const [
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
                value: 'add_balance',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Ajouter au solde'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'set_balance',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Définir le solde'),
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
            ],
          ),
        ],
      ),
      body: async.when(
        data: (c) {
          if (c == null) return const Center(child: Text('Client introuvable'));
          final companyAsync = ref.watch(
            companyOfCustomerProvider(c.companyId),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              final cards = Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Solde'),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.amountFromCents(c.balance),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dette'),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.amountFromCents(c.balanceDebt),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    title: Text(
                      c.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      (c.phone ?? '').isNotEmpty
                          ? (c.phone!)
                          : (c.email ?? '—'),
                    ),
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 8),
                  if (isWide) cards else Column(children: [cards]),
                  const Divider(height: 24),
                  _Info('Téléphone', c.phone ?? '—'),
                  _Info('Email', c.email ?? '—'),
                  _Info('Statut', c.status ?? '—'),
                  companyAsync.when(
                    data: (co) =>
                        _Info('Société', co == null ? '—' : '${co.name}'),
                    loading: () => const _Info('Société', 'Chargement...'),
                    error: (_, __) => const _Info('Société', 'Erreur'),
                  ),
                  const Divider(),
                  _Info(
                    'Adresse',
                    _addr(
                      c.addressLine1,
                      c.addressLine2,
                      c.city,
                      c.region,
                      c.country,
                      c.postalCode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomerLinkedSection(customerId: customerId),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  static String _addr(
    String? l1,
    String? l2,
    String? city,
    String? region,
    String? country,
    String? pc,
  ) {
    final parts = <String>[
      if ((l1 ?? '').trim().isNotEmpty) l1!.trim(),
      if ((l2 ?? '').trim().isNotEmpty) l2!.trim(),
      [city, region].where((e) => (e ?? '').trim().isNotEmpty).join(' ').trim(),
      [pc, country].where((e) => (e ?? '').trim().isNotEmpty).join(' ').trim(),
    ].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join('\n');
  }
}

class _Info extends StatelessWidget {
  final String title;
  final String value;
  const _Info(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}
