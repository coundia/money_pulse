import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/features/pos/state/pos_cart.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'pos_checkout_panel.dart';

class PosCartPanel extends StatefulWidget {
  final PosCart cart;
  final Future<void> Function(
    String typeEntry, {
    String? description,
    String? categoryId,
    DateTime? when,
  })
  onCheckout;
  const PosCartPanel({super.key, required this.cart, required this.onCheckout});

  @override
  State<PosCartPanel> createState() => _PosCartPanelState();
}

class _PosCartPanelState extends State<PosCartPanel> {
  String _money(int c) => (c ~/ 100).toString();

  Future<void> _openCheckout() async {
    if (!mounted) return;
    final res = await showRightDrawer<_CheckoutResult?>(
      context,
      child: PosCheckoutPanel(totalCents: widget.cart.total),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (!mounted || res == null) return;
    await widget.onCheckout(
      res.typeEntry,
      description: res.description,
      categoryId: res.categoryId,
      when: res.when,
    );
    if (!mounted) return;
    Navigator.pop(context, true); // close cart panel
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.cart.snapshot();
    final keys = snapshot.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.cart.isEmpty
                ? null
                : () => setState(() => widget.cart.clear()),
            icon: const Icon(Icons.clear_all),
            label: const Text('Vider'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: snapshot.isEmpty
          ? const Center(child: Text('Panier vide'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: keys.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined),
                        const SizedBox(width: 8),
                        Text('${keys.length} article(s)'),
                        const Spacer(),
                        Text(
                          'Total: ${_money(widget.cart.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }
                final k = keys[i - 1];
                final it = snapshot[k]!;
                return ListTile(
                  title: Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${it.quantity} × ${_money(it.unitPrice)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _money(it.total),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          widget.cart.dec(k);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          widget.cart.inc(k);
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          widget.cart.remove(k);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: widget.cart.isEmpty ? null : _openCheckout,
            icon: const Icon(Icons.point_of_sale),
            label: Text('Encaisser • ${_money(widget.cart.total)}'),
          ),
        ),
      ),
    );
  }
}

/// Result returned by PosCheckoutPanel
class _CheckoutResult {
  final String typeEntry; // 'CREDIT' or 'DEBIT'
  final String? description;
  final String? categoryId;
  final DateTime? when;
  const _CheckoutResult({
    required this.typeEntry,
    this.description,
    this.categoryId,
    this.when,
  });
}
