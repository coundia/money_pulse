import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/transaction_filters.dart';

class TransactionListState {
  final Period period;
  final DateTime anchor;
  final TxnTypeFilter typeFilter;

  const TransactionListState({
    required this.period,
    required this.anchor,
    required this.typeFilter,
  });

  DateTime _startOfWeek(DateTime d) {
    final wd = d.weekday;
    final first = d.subtract(Duration(days: wd - 1));
    return DateTime(first.year, first.month, first.day);
  }

  DateTime get from {
    switch (period) {
      case Period.weekly:
        final s = _startOfWeek(anchor);
        return DateTime(s.year, s.month, s.day);
      case Period.monthly:
        return DateTime(anchor.year, anchor.month, 1);
      case Period.yearly:
        return DateTime(anchor.year, 1, 1);
    }
  }

  DateTime get to {
    switch (period) {
      case Period.weekly:
        final s = _startOfWeek(anchor).add(const Duration(days: 7));
        return DateTime(s.year, s.month, s.day);
      case Period.monthly:
        return DateTime(anchor.year, anchor.month + 1, 1);
      case Period.yearly:
        return DateTime(anchor.year + 1, 1, 1);
    }
  }

  String get label {
    switch (period) {
      case Period.weekly:
        final s = from;
        final e = to.subtract(const Duration(days: 1));
        return '${DateFormat.MMMd().format(s)} – ${DateFormat.MMMd().format(e)}';
      case Period.monthly:
        return DateFormat.yMMMM().format(from);
      case Period.yearly:
        return DateFormat.y().format(from);
    }
  }

  String? get typeEntryString {
    switch (typeFilter) {
      case TxnTypeFilter.expense:
        return 'DEBIT';
      case TxnTypeFilter.income:
        return 'CREDIT';
      case TxnTypeFilter.all:
        return null;
    }
  }

  TransactionListState copyWith({
    Period? period,
    DateTime? anchor,
    TxnTypeFilter? typeFilter,
  }) {
    return TransactionListState(
      period: period ?? this.period,
      anchor: anchor ?? this.anchor,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

class TransactionListController extends StateNotifier<TransactionListState> {
  TransactionListController()
    : super(
        TransactionListState(
          period: Period.monthly,
          anchor: DateTime(DateTime.now().year, DateTime.now().month, 1),
          typeFilter: TxnTypeFilter.all,
        ),
      );

  void prev() {
    switch (state.period) {
      case Period.weekly:
        state = state.copyWith(
          anchor: state.anchor.subtract(const Duration(days: 7)),
        );
        break;
      case Period.monthly:
        state = state.copyWith(
          anchor: DateTime(state.anchor.year, state.anchor.month - 1, 1),
        );
        break;
      case Period.yearly:
        state = state.copyWith(anchor: DateTime(state.anchor.year - 1, 1, 1));
        break;
    }
  }

  void next() {
    switch (state.period) {
      case Period.weekly:
        state = state.copyWith(
          anchor: state.anchor.add(const Duration(days: 7)),
        );
        break;
      case Period.monthly:
        state = state.copyWith(
          anchor: DateTime(state.anchor.year, state.anchor.month + 1, 1),
        );
        break;
      case Period.yearly:
        state = state.copyWith(anchor: DateTime(state.anchor.year + 1, 1, 1));
        break;
    }
  }

  void setPeriod(Period p) {
    switch (p) {
      case Period.weekly:
        final now = DateTime.now();
        final wd = now.weekday;
        final first = now.subtract(Duration(days: wd - 1));
        state = state.copyWith(
          period: p,
          anchor: DateTime(first.year, first.month, first.day),
        );
        break;
      case Period.monthly:
        final now = DateTime.now();
        state = state.copyWith(
          period: p,
          anchor: DateTime(now.year, now.month, 1),
        );
        break;
      case Period.yearly:
        final now = DateTime.now();
        state = state.copyWith(period: p, anchor: DateTime(now.year, 1, 1));
        break;
    }
  }

  void setAnchor(DateTime a) {
    state = state.copyWith(anchor: DateTime(a.year, a.month, a.day));
  }

  void setTypeFilter(TxnTypeFilter f) {
    state = state.copyWith(typeFilter: f);
  }

  void resetToThisPeriod() {
    setPeriod(state.period);
  }
}

final transactionListStateProvider =
    StateNotifierProvider<TransactionListController, TransactionListState>(
      (ref) => TransactionListController(),
    );
