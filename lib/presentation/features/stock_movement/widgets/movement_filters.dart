// Immutable filters model for movements with helpers to apply locally.
import 'package:flutter/material.dart';
import '../../../../domain/stock/repositories/stock_movement_repository.dart';

class MovementFilters {
  final String type;
  final DateTimeRange? range;
  final int minQty;

  const MovementFilters({
    required this.type,
    required this.range,
    required this.minQty,
  });

  const MovementFilters.initial() : type = 'ALL', range = null, minQty = 0;

  MovementFilters copyWith({String? type, DateTimeRange? range, int? minQty}) {
    return MovementFilters(
      type: type ?? this.type,
      range: range ?? this.range,
      minQty: minQty ?? this.minQty,
    );
  }

  List<StockMovementRow> apply(List<StockMovementRow> base) {
    var items = base;
    if (type != 'ALL') {
      items = items.where((e) => e.type == type).toList();
    }
    if (range != null) {
      final start = DateTime(
        range!.start.year,
        range!.start.month,
        range!.start.day,
      );
      final end = DateTime(
        range!.end.year,
        range!.end.month,
        range!.end.day,
        23,
        59,
        59,
        999,
      );
      items = items
          .where(
            (e) =>
                e.createdAt.isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                e.createdAt.isBefore(end.add(const Duration(milliseconds: 1))),
          )
          .toList();
    }
    if (minQty > 0) {
      items = items.where((e) => e.quantity >= minQty).toList();
    }
    return items;
  }
}
