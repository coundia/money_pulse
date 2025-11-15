import 'package:flutter/foundation.dart';
import 'package:jaayko/domain/products/entities/product.dart';

@immutable
class PosCartItem {
  final String? productId; // nullable to allow custom line
  final String label; // product name or custom label
  final int unitPrice; // cents
  final int quantity; // >= 0

  const PosCartItem({
    required this.productId,
    required this.label,
    required this.unitPrice,
    required this.quantity,
  });

  int get total => unitPrice * quantity;

  PosCartItem copyWith({
    String? productId,
    String? label,
    int? unitPrice,
    int? quantity,
  }) {
    return PosCartItem(
      productId: productId ?? this.productId,
      label: label ?? this.label,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PosCart extends ChangeNotifier {
  // key = productId or label for custom
  final Map<String, PosCartItem> _items = {};

  List<PosCartItem> get items => _items.values.toList(growable: false);
  int get countLines => _items.length;
  int get total => _items.values.fold(0, (p, e) => p + e.total);
  bool get isEmpty => _items.isEmpty;

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void addProduct(Product p, {int qty = 1, int? priceCents}) {
    final key = p.id;
    final unit = priceCents ?? p.defaultPrice;
    final existing = _items[key];
    if (existing == null) {
      _items[key] = PosCartItem(
        productId: p.id,
        label: (p.name?.isNotEmpty ?? false) ? p.name! : (p.code ?? 'Produit'),
        unitPrice: unit,
        quantity: qty,
      );
    } else {
      _items[key] = existing.copyWith(quantity: existing.quantity + qty);
    }
    notifyListeners();
  }

  void addCustom({required String label, required int unitPrice, int qty = 1}) {
    final key = 'custom:$label:$unitPrice';
    final existing = _items[key];
    if (existing == null) {
      _items[key] = PosCartItem(
        productId: null,
        label: label,
        unitPrice: unitPrice,
        quantity: qty,
      );
    } else {
      _items[key] = existing.copyWith(quantity: existing.quantity + qty);
    }
    notifyListeners();
  }

  void inc(String key) {
    final it = _items[key];
    if (it == null) return;
    _items[key] = it.copyWith(quantity: it.quantity + 1);
    notifyListeners();
  }

  void dec(String key) {
    final it = _items[key];
    if (it == null) return;
    final q = (it.quantity - 1);
    if (q <= 0) {
      _items.remove(key);
    } else {
      _items[key] = it.copyWith(quantity: q);
    }
    notifyListeners();
  }

  void setQty(String key, int qty) {
    if (qty <= 0) {
      _items.remove(key);
    } else {
      final it = _items[key];
      if (it != null) _items[key] = it.copyWith(quantity: qty);
    }
    notifyListeners();
  }

  void remove(String key) {
    _items.remove(key);
    notifyListeners();
  }

  Map<String, PosCartItem> snapshot() => Map.of(_items);
}
