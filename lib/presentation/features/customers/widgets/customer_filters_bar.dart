// Compact bar showing active customer filters with a quick reset action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_list_providers.dart';
import '../../../app/providers/company_repo_provider.dart';
import 'package:jaayko/domain/company/entities/company.dart';

class ActiveFiltersBar extends ConsumerWidget {
  const ActiveFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(customerSearchProvider);
    final companyId = ref.watch(customerCompanyFilterProvider);
    final onlyActive = ref.watch(customerOnlyActiveProvider);

    final chips = <Widget>[];

    if (search.trim().isNotEmpty) {
      chips.add(
        Chip(
          label: Text('Recherche: "$search"'),
          avatar: const Icon(Icons.search, size: 18),
          onDeleted: () => ref.read(customerSearchProvider.notifier).state = '',
        ),
      );
    }

    if ((companyId ?? '').isNotEmpty) {
      chips.add(_CompanyChip(companyId: companyId!));
    }

    if (!onlyActive) {
      chips.add(
        Chip(
          label: const Text('Inclure inactifs'),
          avatar: const Icon(Icons.visibility, size: 18),
          onDeleted: () =>
              ref.read(customerOnlyActiveProvider.notifier).state = true,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
          TextButton.icon(
            onPressed: () {
              ref.read(customerSearchProvider.notifier).state = '';
              ref.read(customerCompanyFilterProvider.notifier).state = null;
              ref.read(customerOnlyActiveProvider.notifier).state = true;
              ref.read(customerPageIndexProvider.notifier).state = 0;
            },
            icon: const Icon(Icons.restore),
            label: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}

class _CompanyChip extends ConsumerWidget {
  final String companyId;
  const _CompanyChip({required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(companyRepoProvider);
    return FutureBuilder<Company?>(
      future: repo.findById(companyId),
      builder: (context, snap) {
        final name = (snap.data?.name ?? 'Société').toString();
        final code = (snap.data?.code ?? '').toString();
        final label = code.isEmpty ? name : '$name ($code)';
        return Chip(
          label: Text('Société: $label'),
          avatar: const Icon(Icons.business, size: 18),
          onDeleted: () =>
              ref.read(customerCompanyFilterProvider.notifier).state = null,
        );
      },
    );
  }
}
