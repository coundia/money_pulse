// Mini right-drawer confirmation panel shown after a successful order submission.

import 'package:flutter/material.dart';

class OrderConfirmationPanel extends StatelessWidget {
  final String productName;
  final String totalStr;
  final int quantity;

  const OrderConfirmationPanel({
    super.key,
    required this.productName,
    required this.totalStr,
    required this.quantity,
  });

  static const double suggestedWidthFraction = 0.60;
  static const double suggestedHeightFraction = 0.40;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(centerTitle: false, title: const Text('Commande reçue')),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 28, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre commande est en cours de traitement',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '$quantity × • Total: $totalStr',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nous vous contacterons sous peu pour finaliser la commande.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
                label: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
