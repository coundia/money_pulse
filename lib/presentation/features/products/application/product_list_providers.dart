import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/presentation/features/products/product_repo_provider.dart';
import 'package:jaayko/presentation/features/products/product_file_repo_provider.dart';
import 'package:jaayko/presentation/features/products/filters/product_filters.dart';

/// Query string state + debounced controller
final productQueryProvider = StateProvider<String>((ref) => '');

final productQueryControllerProvider = Provider<TextEditingController>((ref) {
  final ctrl = TextEditingController();
  Timer? _debounce;
  ctrl.addListener(() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(productQueryProvider.notifier).state = ctrl.text;
      ref.invalidate(productsFutureProvider);
    });
  });
  ref.onDispose(() {
    _debounce?.cancel();
    ctrl.dispose();
  });
  return ctrl;
});

/// Filters state
final productFiltersProvider = StateProvider<ProductFilters>(
  (_) => const ProductFilters(),
);

/// Core loader (query + filters applied locally)
final productsFutureProvider =
    AsyncNotifierProvider<ProductsFuture, List<Product>>(ProductsFuture.new);

class ProductsFuture extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() => _load();

  Future<List<Product>> _load() async {
    final repo = ref.read(productRepoProvider);
    final q = ref.watch(productQueryProvider).trim();
    final filters = ref.watch(productFiltersProvider);

    List<Product> base;
    if (q.isEmpty) {
      base = await repo.findAllActive();
    } else {
      base = await repo.searchActive(q, limit: 300);
    }
    base.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _applyLocalFilters(base, filters);
  }

  List<Product> _applyLocalFilters(List<Product> base, ProductFilters f) {
    bool matchDate(Product p) {
      if (f.dateRange == null) return true;
      final d = f.dateField == DateField.updated ? p.updatedAt : p.createdAt;
      final start = DateTime(
        f.dateRange!.start.year,
        f.dateRange!.start.month,
        f.dateRange!.start.day,
      );
      final end = DateTime(
        f.dateRange!.end.year,
        f.dateRange!.end.month,
        f.dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      return d.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          d.isBefore(end.add(const Duration(milliseconds: 1)));
    }

    bool matchPrice(Product p) {
      final min = f.minPriceCents;
      final max = f.maxPriceCents;
      if (min != null && p.defaultPrice < min) return false;
      if (max != null && p.defaultPrice > max) return false;
      return true;
    }

    bool matchStock(Product p) {
      if (f.stock == StockFilter.any) return true;
      if (f.stock == StockFilter.inStock) return p.quantity > 0;
      if (f.stock == StockFilter.outOfStock) return p.quantity <= 0;
      return true;
    }

    return base
        .where((p) => matchDate(p) && matchPrice(p) && matchStock(p))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load());
  }
}

/// Build a first-image path map (local files preferred)
final imageMapFutureProvider =
    FutureProvider.family<Map<String, String?>, List<Product>>((
      ref,
      items,
    ) async {
      final fileRepo = ref.read(productFileRepoProvider);
      final result = <String, String?>{};
      for (final p in items) {
        try {
          final rows = await fileRepo.findByProduct(p.id);
          String? found;
          for (final r in rows) {
            final mt = (r.mimeType ?? '').toLowerCase();
            final path = (r.filePath ?? '').trim();
            if (mt.startsWith('image/') && path.isNotEmpty) {
              final f = File(path);
              if (await f.exists()) {
                found = path;
                break;
              }
            }
          }
          result[p.id] = found;
        } catch (_) {
          result[p.id] = null;
        }
      }
      return result;
    });

/// Small helper for stock map (from Product.quantity)
final stockMapFutureProvider =
    FutureProvider.family<Map<String, int>, List<Product>>((ref, items) async {
      final map = <String, int>{};
      for (final p in items) {
        map[p.id] = p.quantity;
      }
      return map;
    });
