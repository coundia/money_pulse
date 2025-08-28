// Report repository for sums and daily totals using UTC ranges, stable grouping, and updated SQL for consistent results.
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/reports/repositories/report_repository.dart';

class ReportRepositorySqflite implements ReportRepository {
  final AppDatabase _db;
  ReportRepositorySqflite(this._db);

  String _isoUtc(DateTime dt) => (dt.isUtc ? dt : dt.toUtc()).toIso8601String();

  @override
  Future<List<Map<String, Object?>>> sumByCategory(
    String accountId, {
    required String typeEntry,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!to.isAfter(from)) return const [];
    final fromIso = _isoUtc(from);
    final toIso = _isoUtc(to);
    final rows = await _db.db.rawQuery(
      '''
      SELECT 
        COALESCE(c.id,'UNCAT')   AS categoryId,
        COALESCE(c.code,'UNCAT') AS categoryCode,
        CAST(SUM(t.amount) AS INTEGER) AS total
      FROM transaction_entry t
      LEFT JOIN category c ON c.id = t.categoryId
      WHERE t.accountId = ? 
        AND t.deletedAt IS NULL 
        AND t.typeEntry = ? 
        AND t.dateTransaction >= ? 
        AND t.dateTransaction <  ?
      GROUP BY COALESCE(c.id,'UNCAT'), COALESCE(c.code,'UNCAT')
      ORDER BY total DESC
      ''',
      [accountId, typeEntry, fromIso, toIso],
    );
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> sumByCategoryLastNDays(
    String accountId, {
    required String typeEntry,
    int days = 30,
  }) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(Duration(days: days));
    return sumByCategory(accountId, typeEntry: typeEntry, from: from, to: now);
  }

  @override
  Future<List<Map<String, Object?>>> sumByCategoryToday(
    String accountId, {
    required String typeEntry,
  }) async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return sumByCategory(accountId, typeEntry: typeEntry, from: start, to: end);
  }

  @override
  Future<List<Map<String, Object?>>> sumByCategoryForMonth(
    String accountId, {
    required String typeEntry,
    required DateTime month,
  }) async {
    final start = DateTime.utc(month.year, month.month, 1);
    final end = (month.month == 12)
        ? DateTime.utc(month.year + 1, 1, 1)
        : DateTime.utc(month.year, month.month + 1, 1);
    return sumByCategory(accountId, typeEntry: typeEntry, from: start, to: end);
  }

  @override
  Future<List<Map<String, Object?>>> dailyTotals(
    String accountId, {
    required String typeEntry,
    int days = 30,
  }) async {
    final cutoffIso = _isoUtc(
      DateTime.now().toUtc().subtract(Duration(days: days)),
    );
    final rows = await _db.db.rawQuery(
      '''
      SELECT 
        strftime('%Y-%m-%d', t.dateTransaction) AS day, 
        CAST(SUM(t.amount) AS INTEGER) AS total
      FROM transaction_entry t
      WHERE t.accountId = ? 
        AND t.deletedAt IS NULL 
        AND t.typeEntry = ? 
        AND t.dateTransaction >= ?
      GROUP BY day
      ORDER BY day ASC
      ''',
      [accountId, typeEntry, cutoffIso],
    );
    return rows;
  }
}
