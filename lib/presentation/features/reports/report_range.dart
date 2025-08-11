import 'package:flutter/material.dart';

enum ReportRangeKind { today, thisWeek, thisMonth, thisYear, custom }

@immutable
class ReportRange {
  final ReportRangeKind kind;
  final DateTime from; // inclus
  final DateTime to; // exclus (standard SQL-like [from, to) )
  const ReportRange({required this.kind, required this.from, required this.to});

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  static ReportRange today() {
    final now = DateTime.now();
    final start = _strip(now);
    final end = start.add(const Duration(days: 1));
    return ReportRange(kind: ReportRangeKind.today, from: start, to: end);
  }

  static ReportRange thisWeek({int firstWeekday = DateTime.monday}) {
    final now = DateTime.now();
    final today = _strip(now);
    final delta = (today.weekday - firstWeekday) % 7;
    final start = today.subtract(Duration(days: delta));
    final end = start.add(const Duration(days: 7));
    return ReportRange(kind: ReportRangeKind.thisWeek, from: start, to: end);
  }

  static ReportRange thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return ReportRange(kind: ReportRangeKind.thisMonth, from: start, to: end);
  }

  static ReportRange thisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return ReportRange(kind: ReportRangeKind.thisYear, from: start, to: end);
  }

  static ReportRange custom(DateTime start, DateTime endExclusive) {
    return ReportRange(
      kind: ReportRangeKind.custom,
      from: _strip(start),
      to: _strip(endExclusive),
    );
  }

  bool get isCustom => kind == ReportRangeKind.custom;
}
