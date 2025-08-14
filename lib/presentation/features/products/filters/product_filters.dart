import 'package:flutter/material.dart';

enum DateField { created, updated }

enum StockFilter { any, inStock, outOfStock }

class ProductFilters {
  final DateField dateField;
  final DateTimeRange? dateRange;
  final int? minPriceCents;
  final int? maxPriceCents;
  final StockFilter stock;

  const ProductFilters({
    this.dateField = DateField.updated,
    this.dateRange,
    this.minPriceCents,
    this.maxPriceCents,
    this.stock = StockFilter.any,
  });

  bool get hasAny =>
      dateRange != null ||
      minPriceCents != null ||
      maxPriceCents != null ||
      stock != StockFilter.any;

  ProductFilters copyWith({
    DateField? dateField,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    int? minPriceCents,
    bool clearMin = false,
    int? maxPriceCents,
    bool clearMax = false,
    StockFilter? stock,
  }) {
    return ProductFilters(
      dateField: dateField ?? this.dateField,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minPriceCents: clearMin ? null : (minPriceCents ?? this.minPriceCents),
      maxPriceCents: clearMax ? null : (maxPriceCents ?? this.maxPriceCents),
      stock: stock ?? this.stock,
    );
  }
}
