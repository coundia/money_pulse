// Right drawer confirmation panel to delete a StockLevel with ENTER support.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/stock_level_repo_provider.dart';

class StockLevelDeletePanel extends ConsumerWidget {
  final String itemId;
  const StockLevelDeletePanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> _confirm() async {
      await ref.read(stockLevelRepoProvider).delete(itemId);
      if (context.mounted) Navigator.of(context).pop(true);
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _confirm();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Supprimer le stock')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Voulez-vous vraiment supprimer ce niveau de stock ?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _confirm,
                          icon: const Icon(Icons.delete),
                          label: const Text('Supprimer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.of(context).maybePop(false),
                          icon: const Icon(Icons.close),
                          label: const Text('Annuler'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Astuce : appuyez sur Entrée pour confirmer.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
