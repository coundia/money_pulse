/* Sqflite adapters implementing sync ports: findDirty + markSynced per table. */
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/sync/application/_ports.dart';

class _Sql {
  static String inClause(int n) => List.filled(n, '?').join(',');
  static Future<void> markSyncedStringIds(
    Database db,
    String table,
    Iterable<String> ids,
    DateTime at,
  ) async {
    if (ids.isEmpty) return;
    final placeholders = inClause(ids.length);
    final iso = at.toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE $table SET isDirty=0, syncAt=?, updatedAt=? WHERE id IN ($placeholders)',
      [iso, iso, ...ids],
    );
  }

  static Future<void> markSyncedIntIds(
    Database db,
    String table,
    Iterable<int> ids,
    DateTime at,
  ) async {
    if (ids.isEmpty) return;
    final placeholders = inClause(ids.length);
    final iso = at.toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE $table SET isDirty=0, syncAt=?, updatedAt=? WHERE id IN ($placeholders)',
      [iso, iso, ...ids],
    );
  }
}

class CategorySyncPortSqflite implements CategorySyncPort {
  final Database db;
  CategorySyncPortSqflite(this.db);

  @override
  Future<List<Category>> findDirty({int limit = 200}) async {
    final rows = await db.rawQuery(
      'SELECT * FROM category WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
      [limit],
    );
    return rows.map((m) => Category.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'category', ids, syncedAt);
}

class AccountSyncPortSqflite implements AccountSyncPort {
  final Database db;
  AccountSyncPortSqflite(this.db);

  @override
  Future<List<Account>> findDirty({int limit = 200}) async {
    final rows = await db.rawQuery(
      'SELECT * FROM account WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
      [limit],
    );
    return rows.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'account', ids, syncedAt);
}

class TransactionSyncPortSqflite implements TransactionSyncPort {
  final Database db;
  TransactionSyncPortSqflite(this.db);

  @override
  Future<List<TransactionEntry>> findDirty({int limit = 200}) async {
    final rows = await db.rawQuery(
      'SELECT * FROM transaction_entry WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC, datetime(dateTransaction) DESC LIMIT ?',
      [limit],
    );
    return rows.map((m) => TransactionEntry.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'transaction_entry', ids, syncedAt);
}

class UnitSyncPortSqflite implements UnitSyncPort {
  final Database db;
  UnitSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM unit WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'unit', ids, syncedAt);
}

class ProductSyncPortSqflite implements ProductSyncPort {
  final Database db;
  ProductSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM product WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'product', ids, syncedAt);
}

class TransactionItemSyncPortSqflite implements TransactionItemSyncPort {
  final Database db;
  TransactionItemSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM transaction_item WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'transaction_item', ids, syncedAt);
}

class CompanySyncPortSqflite implements CompanySyncPort {
  final Database db;
  CompanySyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM company WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'company', ids, syncedAt);
}

class CustomerSyncPortSqflite implements CustomerSyncPort {
  final Database db;
  CustomerSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM customer WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'customer', ids, syncedAt);
}

class DebtSyncPortSqflite implements DebtSyncPort {
  final Database db;
  DebtSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM debt WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt) =>
      _Sql.markSyncedStringIds(db, 'debt', ids, syncedAt);
}

class StockLevelSyncPortSqflite implements StockLevelSyncPort {
  final Database db;
  StockLevelSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM stock_level WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<int> ids, DateTime syncedAt) =>
      _Sql.markSyncedIntIds(db, 'stock_level', ids, syncedAt);
}

class StockMovementSyncPortSqflite implements StockMovementSyncPort {
  final Database db;
  StockMovementSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({
    int limit = 200,
  }) => db.rawQuery(
    'SELECT * FROM stock_movement WHERE isDirty=1 ORDER BY datetime(updatedAt) DESC LIMIT ?',
    [limit],
  );

  @override
  Future<void> markSynced(Iterable<int> ids, DateTime syncedAt) =>
      _Sql.markSyncedIntIds(db, 'stock_movement', ids, syncedAt);
}
