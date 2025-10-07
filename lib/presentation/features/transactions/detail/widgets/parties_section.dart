// lib/presentation/features/transactions/detail/widgets/parties_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'section_card.dart';

class PartiesSection extends StatelessWidget {
  final AsyncValue companyAsync;
  final AsyncValue customerAsync;

  const PartiesSection({
    super.key,
    required this.companyAsync,
    required this.customerAsync,
  });

  @override
  Widget build(BuildContext context) {
    final company = companyAsync.maybeWhen(data: (v) => v, orElse: () => null);
    final customer = customerAsync.maybeWhen(
      data: (v) => v,
      orElse: () => null,
    );
    if (company == null && customer == null) return const SizedBox.shrink();

    String companyLabel(String? name, String? code) {
      final n = (name ?? '').trim();
      final c = (code ?? '').trim();
      if (n.isNotEmpty && c.isNotEmpty) return '$n ($c)';
      if (n.isNotEmpty) return n;
      if (c.isNotEmpty) return c;
      return '—';
    }

    String customerLabel(String fullName, String? email, String? phone) {
      final e = (email ?? '').trim();
      final p = (phone ?? '').trim();
      if (e.isNotEmpty && p.isNotEmpty) return '$fullName • $e • $p';
      if (e.isNotEmpty) return '$fullName • $e';
      if (p.isNotEmpty) return '$fullName • $p';
      return fullName.isEmpty ? '—' : fullName;
    }

    return SectionCard(
      title: 'Tiers',
      children: [
        if (company != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Société'),
            subtitle: Text(companyLabel(company.name, company.code)),
          ),
        if (customer != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: const Text('Client'),
            subtitle: Text(
              customerLabel(customer.fullName, customer.email, customer.phone),
            ),
          ),
      ],
    );
  }
}
