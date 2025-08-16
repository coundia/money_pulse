// Lightweight filter state and enums for transaction search, with extended type groups.

import 'package:flutter/foundation.dart';

enum TxnTypeFilter { all, expense, income, debt, loan, reimbursement }

enum TxnSortBy { dateDesc, dateAsc, amountDesc, amountAsc }

@immutable
class TxnFilterState {
  final TxnTypeFilter type;
  final DateTime? from;
  final DateTime? to;
  final int? minCents;
  final int? maxCents;
  final TxnSortBy sortBy;

  const TxnFilterState({
    this.type = TxnTypeFilter.all,
    this.from,
    this.to,
    this.minCents,
    this.maxCents,
    this.sortBy = TxnSortBy.dateDesc,
  });

  TxnFilterState copyWith({
    TxnTypeFilter? type,
    DateTime? from,
    DateTime? to,
    int? minCents,
    int? maxCents,
    TxnSortBy? sortBy,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearMin = false,
    bool clearMax = false,
  }) {
    return TxnFilterState(
      type: type ?? this.type,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      minCents: clearMin ? null : (minCents ?? this.minCents),
      maxCents: clearMax ? null : (maxCents ?? this.maxCents),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  int get hashCode => Object.hash(type, from, to, minCents, maxCents, sortBy);

  @override
  bool operator ==(Object other) {
    return other is TxnFilterState &&
        other.type == type &&
        other.from == from &&
        other.to == to &&
        other.minCents == minCents &&
        other.maxCents == maxCents &&
        other.sortBy == sortBy;
  }
}
