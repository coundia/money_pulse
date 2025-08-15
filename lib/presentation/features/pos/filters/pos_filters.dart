// Defines POS filter value object with copyWith.
import 'package:flutter/foundation.dart';

@immutable
class PosFilters {
  final bool inStockOnly;
  final String? categoryId;
  final String? categoryLabel;
  final int? minPriceCents;
  final int? maxPriceCents;

  const PosFilters({
    this.inStockOnly = false,
    this.categoryId,
    this.categoryLabel,
    this.minPriceCents,
    this.maxPriceCents,
  });

  PosFilters copyWith({
    bool? inStockOnly,
    String? categoryId,
    String? categoryLabel,
    int? minPriceCents,
    int? maxPriceCents,
  }) {
    return PosFilters(
      inStockOnly: inStockOnly ?? this.inStockOnly,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      minPriceCents: minPriceCents ?? this.minPriceCents,
      maxPriceCents: maxPriceCents ?? this.maxPriceCents,
    );
  }
}
