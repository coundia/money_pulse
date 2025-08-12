import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'providers/customer_detail_providers.dart';

class CustomerViewPanel extends ConsumerWidget {
  final String customerId;
  const CustomerViewPanel({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerByIdProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails client'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: async.when(
        data: (c) {
          if (c == null) return const Center(child: Text('Client introuvable'));
          final companyAsync = ref.watch(
            companyOfCustomerProvider(c.companyId),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(
                  c.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text((c.code ?? '').isEmpty ? '—' : c.code!),
                leading: const CircleAvatar(child: Icon(Icons.person)),
              ),
              const Divider(),
              _Info('Téléphone', c.phone ?? '—'),
              _Info('Email', c.email ?? '—'),
              _Info('Statut', c.status ?? '—'),
              companyAsync.when(
                data: (co) => _Info(
                  'Société',
                  co == null ? '—' : '${co.name} (${co.code})',
                ),
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
              const Divider(),
              _Info('Créé le', Formatters.dateFull(c.createdAt)),
              _Info('Mis à jour', Formatters.dateFull(c.updatedAt)),
              const Divider(),
              _Info('Identifiant', c.id),
              if ((c.notes ?? '').trim().isNotEmpty) ...[
                const Divider(),
                _Info('Notes', c.notes!),
              ],
            ],
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
