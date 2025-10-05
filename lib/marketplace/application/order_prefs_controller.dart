// Riverpod state for last order form values with load/save to OrderLocalStore. Exposes update & clear.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../marketplace/infrastructure/order_local_store.dart';

class OrderPrefs {
  final String? buyerName;
  final String? phone;
  final String? address;
  final String? note;
  final int? quantity;
  final int? amountCents;
  final String? paymentMethod;
  final String? deliveryMethod;

  const OrderPrefs({
    this.buyerName,
    this.phone,
    this.address,
    this.note,
    this.quantity,
    this.amountCents,
    this.paymentMethod,
    this.deliveryMethod,
  });

  OrderPrefs copyWith({
    String? buyerName,
    String? phone,
    String? address,
    String? note,
    int? quantity,
    int? amountCents,
    String? paymentMethod,
    String? deliveryMethod,
  }) {
    return OrderPrefs(
      buyerName: buyerName ?? this.buyerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      quantity: quantity ?? this.quantity,
      amountCents: amountCents ?? this.amountCents,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
    );
  }

  Map<String, dynamic> toJson() => {
    'buyerName': buyerName,
    'phone': phone,
    'address': address,
    'note': note,
    'quantity': quantity,
    'amountCents': amountCents,
    'paymentMethod': paymentMethod,
    'deliveryMethod': deliveryMethod,
  };

  static OrderPrefs fromJson(Map<String, dynamic> m) => OrderPrefs(
    buyerName: m['buyerName'] as String?,
    phone: m['phone'] as String?,
    address: m['address'] as String?,
    note: m['note'] as String?,
    quantity: m['quantity'] is int
        ? m['quantity'] as int
        : int.tryParse('${m['quantity'] ?? ''}'),
    amountCents: m['amountCents'] is int
        ? m['amountCents'] as int
        : int.tryParse('${m['amountCents'] ?? ''}'),
    paymentMethod: m['paymentMethod'] as String?,
    deliveryMethod: m['deliveryMethod'] as String?,
  );
}

final orderLocalStoreProvider = Provider((ref) => OrderLocalStore());

final orderPrefsProvider =
    StateNotifierProvider<OrderPrefsController, AsyncValue<OrderPrefs>>((ref) {
      return OrderPrefsController(ref);
    });

class OrderPrefsController extends StateNotifier<AsyncValue<OrderPrefs>> {
  final Ref ref;
  OrderPrefsController(this.ref) : super(const AsyncLoading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(orderLocalStoreProvider);
      final json = await store.load();
      state = AsyncData(
        json == null ? const OrderPrefs() : OrderPrefs.fromJson(json),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> save(OrderPrefs prefs) async {
    state = AsyncData(prefs);
    final store = ref.read(orderLocalStoreProvider);
    await store.save(prefs.toJson());
  }

  Future<void> clear() async {
    state = const AsyncData(OrderPrefs());
    final store = ref.read(orderLocalStoreProvider);
    await store.clear();
  }

  Future<void> patch(Map<String, dynamic> partial) async {
    final current = state.value ?? const OrderPrefs();
    final next = current.copyWith(
      buyerName: partial['buyerName'] as String? ?? current.buyerName,
      phone: partial['phone'] as String? ?? current.phone,
      address: partial['address'] as String? ?? current.address,
      note: partial['note'] as String? ?? current.note,
      quantity: partial['quantity'] as int? ?? current.quantity,
      amountCents: partial['amountCents'] as int? ?? current.amountCents,
      paymentMethod:
          partial['paymentMethod'] as String? ?? current.paymentMethod,
      deliveryMethod:
          partial['deliveryMethod'] as String? ?? current.deliveryMethod,
    );
    await save(next);
  }
}
