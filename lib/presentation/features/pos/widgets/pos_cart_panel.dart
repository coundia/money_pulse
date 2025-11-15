// POS cart right-drawer panel; now forwards customerId from checkout payload to onCheckout.
import 'package:flutter/material.dart';
import 'package:jaayko/presentation/features/pos/state/pos_cart.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import 'pos_checkout_panel.dart';

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
  final Future<void> Function(
    String typeEntry, {
    String? description,
    String? categoryId,
    String? customerId, // NEW
    DateTime? when,
  })
  onCheckout;

  const PosCartPanel({super.key, required this.cart, required this.onCheckout});

  @override
  State<PosCartPanel> createState() => _PosCartPanelState();
}

class _PosCartPanelState extends State<PosCartPanel> {
  bool _closing = false;

  String _money(int c) => Formatters.amountFromCents(c);

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

    final snapshot = widget.cart.snapshot();
    final keys = snapshot.keys.toList();
    final lines = keys.map((k) {
      final it = snapshot[k]!;
      final productId = it.productId;
      return PosCartLine(
        productId: productId,
        label: it.label,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
      );
    }).toList();

    final res = await showRightDrawer<dynamic>(
      context,
      child: PosCheckoutPanel(lines: lines),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );

    if (!mounted) return;
    if (res == null || res == false) return;

    String typeEntry = 'CREDIT';
    DateTime when = DateTime.now();
    String? description;
    String? categoryId;
    String? customerId; // NEW

    if (res is Map) {
      final te = res['typeEntry'] as String?;
      final w = res['when'];
      final desc = res['description'] as String?;
      final cat = res['categoryId'] as String?;
      final cust = res['customerId'] as String?; // NEW

      if (te == 'DEBIT' || te == 'CREDIT') typeEntry = te!;
      if (w is DateTime) when = w;
      if (w is String) {
        final parsed = DateTime.tryParse(w);
        if (parsed != null) when = parsed;
      }
      description = desc;
      categoryId = cat;
      customerId = cust; // NEW
    }

    await widget.onCheckout(
      typeEntry,
      description: description,
      categoryId: categoryId,
      customerId: customerId, // NEW
      when: when,
    );

    if (!mounted) return;
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
            label: const Text('Encaisser'),
          ),
        ),
      ),
    );
  }
}
