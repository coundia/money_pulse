import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/reports/repositories/report_repository.dart';

class ReportRepositorySqflite implements ReportRepository {
  final AppDatabase _db;
  ReportRepositorySqflite(this._db);

  @override
  Future<List<Map<String, Object?>>> sumByCategory(
    String accountId, {
    required String typeEntry,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromIso = from.toIso8601String();
    final toIso = to.toIso8601String();
    final rows = await _db.db.rawQuery(
      '''
      SELECT COALESCE(c.code,'UNCAT') AS categoryCode, SUM(t.amount) AS total
      FROM transaction_entry t
      LEFT JOIN category c ON c.id = t.categoryId
      WHERE t.accountId = ? 
        AND t.deletedAt IS NULL 
        AND t.typeEntry = ? 
        AND t.dateTransaction >= ? 
        AND t.dateTransaction <  ?
      GROUP BY COALESCE(c.code,'UNCAT')
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
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    return sumByCategory(accountId, typeEntry: typeEntry, from: from, to: now);
  }

  @override
  Future<List<Map<String, Object?>>> sumByCategoryToday(
    String accountId, {
    required String typeEntry,
  }) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 1));
    return sumByCategory(accountId, typeEntry: typeEntry, from: from, to: to);
  }

  @override
  Future<List<Map<String, Object?>>> sumByCategoryForMonth(
    String accountId, {
    required String typeEntry,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return sumByCategory(accountId, typeEntry: typeEntry, from: start, to: end);
  }

  @override
  Future<List<Map<String, Object?>>> dailyTotals(
    String accountId, {
    required String typeEntry,
    int days = 30,
  }) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    final rows = await _db.db.rawQuery(
      '''
      SELECT date(t.dateTransaction) AS day, SUM(t.amount) AS total
      FROM transaction_entry t
      WHERE t.accountId = ? 
        AND t.deletedAt IS NULL 
        AND t.typeEntry = ? 
        AND t.dateTransaction >= ?
      GROUP BY date(t.dateTransaction)
      ORDER BY day ASC
    ''',
      [accountId, typeEntry, cutoff],
    );
    return rows;
  }
}
