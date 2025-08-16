// Section that composes the header and a compact footer with a transactions button (popup).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_linked_header.dart';
import 'customer_linked_controller.dart';

class CustomerLinkedSection extends ConsumerWidget {
  final String customerId;
  const CustomerLinkedSection({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = CustomerLinkedController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomerLinkedHeader(customerId: customerId),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transactions récentes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => controller.openTransactionsPopup(
                    context,
                    ref,
                    customerId,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ouvrir'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
