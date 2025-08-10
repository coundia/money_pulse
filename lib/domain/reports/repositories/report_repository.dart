abstract class ReportRepository {
  /// Sum of amounts grouped by category code in [from, to).
  /// [typeEntry] = 'DEBIT' (expense) or 'CREDIT' (income)
  Future<List<Map<String, Object?>>> sumByCategory(
    String accountId, {
    required String typeEntry,
    required DateTime from,
    required DateTime to,
  });

  /// Convenience: last [days] days until now.
  Future<List<Map<String, Object?>>> sumByCategoryLastNDays(
    String accountId, {
    required String typeEntry, // 'DEBIT' | 'CREDIT'
    int days = 30,
  });

  /// Convenience: from today 00:00 (local) to tomorrow 00:00.
  Future<List<Map<String, Object?>>> sumByCategoryToday(
    String accountId, {
    required String typeEntry, // 'DEBIT' | 'CREDIT'
  });

  /// NEW: whole calendar month (local). [month] can be any date inside the month.
  Future<List<Map<String, Object?>>> sumByCategoryForMonth(
    String accountId, {
    required String typeEntry, // 'DEBIT' | 'CREDIT'
    required DateTime month,
  });

  /// Optional: daily totals time series for charts.
  Future<List<Map<String, Object?>>> dailyTotals(
    String accountId, {
    required String typeEntry, // 'DEBIT' | 'CREDIT'
    int days = 30,
  });
}
