// Stock utilities for POS grid: compute per-product stock and in-stock filter.
import 'package:money_pulse/domain/products/entities/product.dart';

Future<Map<String, int>> computeStockMap(
  dynamic stockRepo,
  List<Product> items,
) async {
  final map = <String, int>{};
  for (final p in items) {
    final q = (p.code?.trim().isNotEmpty ?? false)
        ? p.code!.trim()
        : (p.name?.trim() ?? '');
    if (q.isEmpty) {
      map[p.id] = 0;
      continue;
    }
    final rows = await stockRepo.search(query: q);
    final relevant = rows.where((r) {
      if ((p.code ?? '').isNotEmpty) {
        return r.productLabel.toLowerCase().contains(p.code!.toLowerCase());
      }
      if ((p.name ?? '').isNotEmpty) {
        return r.productLabel.toLowerCase().contains(p.name!.toLowerCase());
      }
      return true;
    });
    final total = relevant.fold<int>(
      0,
      (prev, e) => prev + (e.stockOnHand - e.stockAllocated),
    );
    map[p.id] = total;
  }
  return map;
}

List<Product> applyInStockOnly({
  required List<Product> items,
  required Map<String, int> stockByProduct,
  required bool inStockOnly,
}) {
  if (!inStockOnly) return items;
  return items.where((p) => (stockByProduct[p.id] ?? 0) > 0).toList();
}
