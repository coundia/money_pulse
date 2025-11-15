import 'package:flutter/material.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/domain/customer/entities/customer.dart';

import 'customer_autocomplete.dart';

typedef OnCompanyChanged = void Function(String? companyId);
typedef OnCustomerChanged = void Function(String? customerId);

class PartySection extends StatelessWidget {
  final List<Company> companies;
  final List<Customer> customers;
  final String? companyId;
  final String? customerId;

  final bool isDebit;
  final int itemsCount;

  final OnCompanyChanged onCompanyChanged;
  final OnCustomerChanged onCustomerChanged;

  /// Optional: override the create flow (e.g., open your own drawer).
  /// If not provided, CustomerAutocomplete opens CustomerFormPanel by itself.
  final Future<Customer?> Function()? onCreateCustomer;

  const PartySection({
    super.key,
    required this.companies,
    required this.customers,
    required this.companyId,
    required this.customerId,
    required this.itemsCount,
    required this.isDebit,
    required this.onCompanyChanged,
    required this.onCustomerChanged,
    this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCompany = companies
        .where((c) => c.id == companyId)
        .cast<Company?>()
        .firstOrNull;
    final selectedCustomer = customers
        .where((c) => c.id == customerId)
        .cast<Customer?>()
        .firstOrNull;

    // Local controller for the customer field (kept in sync each build)
    final customerCtrl = TextEditingController(
      text: selectedCustomer?.fullName ?? '',
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tiers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Company
            DropdownButtonFormField<String?>(
              value: companyId,
              isDense: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Aucune société —'),
                ),
                ...companies.map(
                  (co) => DropdownMenuItem<String?>(
                    value: co.id,
                    child: Text(
                      '${co.name} (${co.code})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onCompanyChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Société',
                isDense: true,
              ),
            ),

            const SizedBox(height: 8),

            // Customer (Autocomplete with inline "Create")
            CustomerAutocomplete(
              controller: customerCtrl,
              initialSelected: selectedCustomer,
              companyLabel: selectedCompany?.name,
              onCreate: onCreateCustomer, // optional override
              optionsBuilder: (query) {
                final q = query.toLowerCase().trim();
                final base = customers.where((c) {
                  // keep in-company results first if company selected
                  if ((companyId ?? '').isNotEmpty) {
                    return c.companyId == companyId;
                  }
                  return true;
                });
                if (q.isEmpty) return base.toList();
                return base.where((c) {
                  final code = (c.code ?? '').toLowerCase();
                  final full = c.fullName.toLowerCase();
                  final phone = (c.phone ?? '').toLowerCase();
                  final email = (c.email ?? '').toLowerCase();
                  return full.contains(q) ||
                      code.contains(q) ||
                      phone.contains(q) ||
                      email.contains(q);
                }).toList();
              },
              onSelected: (c) => onCustomerChanged(c.id),
              onClear: () => onCustomerChanged(null),
              labelText: 'Client',
              emptyHint: 'Aucun client dans cette société',
            ),

            const SizedBox(height: 8),

            if (itemsCount > 0)
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isDebit
                          ? 'Le stock sera augmenté pour $itemsCount produit(s) dans la société sélectionnée.'
                          : 'Le stock sera diminué pour $itemsCount produit(s) dans la société sélectionnée.',
                      overflow: TextOverflow.ellipsis,
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

// tiny safe extension
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
