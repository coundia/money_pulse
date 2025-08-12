import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/features/pos/state/pos_cart.dart';

class PosCartTile extends StatelessWidget {
  final String keyId; // key inside cart map
  final PosCartItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const PosCartTile({
    super.key,
    required this.keyId,
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  String _money(int c) => (c ~/ 100).toString();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.quantity} × ${_money(item.unitPrice)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _money(item.total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.remove), onPressed: onDec),
          IconButton(icon: const Icon(Icons.add), onPressed: onInc),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
