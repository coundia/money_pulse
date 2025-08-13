// Right drawer panel to confirm deletion of a StockLevel

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/stock_level_repo_provider.dart';

class StockLevelDeletePanel extends ConsumerStatefulWidget {
  final String itemId;
  const StockLevelDeletePanel({super.key, required this.itemId});

  @override
  ConsumerState<StockLevelDeletePanel> createState() =>
      _StockLevelDeletePanelState();
}

class _StockLevelDeletePanelState extends ConsumerState<StockLevelDeletePanel> {
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(stockLevelRepoProvider);
      await repo.delete(widget.itemId);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supprimer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirmer la suppression de ce niveau de stock ?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _delete,
                          icon: const Icon(Icons.delete),
                          label: Text(_busy ? 'Suppression…' : 'Supprimer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).maybePop(false),
                          icon: const Icon(Icons.close),
                          label: const Text('Annuler'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
