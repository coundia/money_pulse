import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/features/pos/state/pos_cart.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'pos_checkout_panel.dart';

/// Optional adapter if your PosCart items don’t expose productId.
/// Adjust to your real PosCartItem type if needed.
class _CartLineAdapter {
  final String? productId;
  final String label;
  final int quantity;
  final int unitPrice;
  const _CartLineAdapter({
    required this.label,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });
}

class PosCartPanel extends StatefulWidget {
  final PosCart cart;

  /// Persist the sale/purchase after the user confirms in checkout.
  /// typeEntry: 'CREDIT' (sale) or 'DEBIT' (purchase)
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
  bool _closing = false;

  String _money(int c) => (c ~/ 100).toString();

  Future<void> _safePop([dynamic result]) async {
    if (_closing) return;
    _closing = true;
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(result);
  }

  Future<void> _openCheckout() async {
    if (!mounted) return;

    // Build checkout lines from the cart snapshot
    final snapshot = widget.cart.snapshot(); // Map<String, PosCartItem>
    final keys = snapshot.keys.toList();
    final lines = keys.map((k) {
      final it = snapshot[k]!;
      // If your PosCartItem has productId, map it; otherwise keep null
      final productId = it.productId; // adjust if different in your model
      return PosCartLine(
        productId: productId,
        label: it.label,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
      );
    }).toList();

    // Open checkout. Your PosCheckoutPanel (from earlier) returns `true` on confirm.
    // If you later upgrade it to return a payload (map/class), the adapter below will handle it.
    final res = await showRightDrawer<dynamic>(
      context,
      child: PosCheckoutPanel(
        lines: lines,
        // You can pass initial values if you need:
        // initialTypeEntry: 'CREDIT',
        // initialDescription: null,
        // initialWhen: DateTime.now(),
        // accountLabel: 'Compte X',
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );

    if (!mounted) return;

    // Nothing confirmed
    if (res == null || res == false) return;

    // Try to adapt whatever the checkout returned:
    // 1) If it returned a custom class with fields
    String typeEntry = 'CREDIT';
    String? description;
    String? categoryId;
    DateTime? when;

    try {
      // If your checkout returns a class with these getters:
      // ignore: avoid_dynamic_calls
      final te = (res as dynamic).typeEntry as String?;
      // ignore: avoid_dynamic_calls
      final desc = (res as dynamic).description as String?;
      // ignore: avoid_dynamic_calls
      final cat = (res as dynamic).categoryId as String?;
      // ignore: avoid_dynamic_calls
      final w = (res as dynamic).when as DateTime?;
      if (te != null) typeEntry = te;
      description = desc;
      categoryId = cat;
      when = w;
    } catch (_) {
      // 2) If a Map payload
      if (res is Map) {
        final te = res['typeEntry'] as String?;
        final desc = res['description'] as String?;
        final cat = res['categoryId'] as String?;
        final w = res['when'];
        if (te != null) typeEntry = te;
        description = desc;
        categoryId = cat;
        if (w is DateTime) when = w;
        if (w is String) {
          try {
            when = DateTime.tryParse(w);
          } catch (_) {}
        }
      } else {
        // 3) If it’s just `true`, keep sensible defaults
        typeEntry = 'CREDIT';
      }
    }

    // Persist via injected callback
    await widget.onCheckout(
      typeEntry,
      description: description,
      categoryId: categoryId,
      when: when,
    );

    if (!mounted) return;
    // Close the cart panel after successful checkout
    await _safePop(true);
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
          onPressed: () => _safePop(false),
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
        top: false,
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
