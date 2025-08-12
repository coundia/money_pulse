import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/customer_repo_provider.dart';

class CustomerDeletePanel extends ConsumerWidget {
  final String customerId;
  const CustomerDeletePanel({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supprimer le client'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: Text('Confirmer la suppression ?'),
              subtitle: Text('Cette action peut être annulée (soft delete).'),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await ref
                          .read(customerRepoProvider)
                          .softDelete(customerId);
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    child: const Text('Supprimer'),
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
