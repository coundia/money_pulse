// party_section.dart
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';

class PartySection extends StatelessWidget {
  final List<Company> companies;
  final List<Customer> customers;
  final String? companyId;
  final String? customerId;
  final int itemsCount;
  final bool isDebit;

  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onCustomerChanged;
  final VoidCallback onCreateCustomer;

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
    required this.onCreateCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final safeCompanyId =
        (companyId != null && companies.any((c) => c.id == companyId))
        ? companyId
        : null;

    final safeCustomerId =
        (customerId != null && customers.any((c) => c.id == customerId))
        ? customerId
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tiers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: safeCompanyId, // SAFE
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: safeCustomerId, // SAFE
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Aucun client —'),
                      ),
                      ...customers.map(
                        (cu) => DropdownMenuItem<String?>(
                          value: cu.id,
                          child: Text(
                            cu.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onCustomerChanged,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Client',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onCreateCustomer,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Nouveau client'),
                ),
              ],
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
