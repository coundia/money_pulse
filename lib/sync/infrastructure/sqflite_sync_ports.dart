/* Sqflite SyncPorts for all tables with robust findDirty (dirty or never-synced) and markSynced. */
import 'package:sqflite/sqflite.dart';

import 'package:money_pulse/sync/application/_ports.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

class _Sql {
  static String listQ(int n) => List.filled(n, '?').join(', ');
  static const commonWhere = 'remoteId IS NULL AND deletedAt IS NULL';
  static const order = 'updatedAt DESC';
}

class CategorySyncPortSqflite implements CategorySyncPort {
  final Database db;
  CategorySyncPortSqflite(this.db);

  @override
  Future<List<Category>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      'category',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final b = db.batch();
    for (final id in ids) {
      b.update(
        'category',
        {'isDirty': 0, 'syncAt': ts, 'updatedAt': ts},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await b.commit(noResult: true);
  }
}

class AccountSyncPortSqflite implements AccountSyncPort {
  final Database db;
  AccountSyncPortSqflite(this.db);

  @override
  Future<List<Account>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      'account',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final b = db.batch();
    for (final id in ids) {
      b.update(
        'account',
        {'isDirty': 0, 'syncAt': ts, 'updatedAt': ts},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await b.commit(noResult: true);
  }
}

class TransactionSyncPortSqflite implements TransactionSyncPort {
  final Database db;
  TransactionSyncPortSqflite(this.db);

  @override
  Future<List<TransactionEntry>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      'transaction_entry',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final b = db.batch();
    for (final id in ids) {
      b.update(
        'transaction_entry',
        {'isDirty': 0, 'syncAt': ts, 'updatedAt': ts},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await b.commit(noResult: true);
  }
}

class UnitSyncPortSqflite implements UnitSyncPort {
  final Database db;
  UnitSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'unit',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE unit SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class ProductSyncPortSqflite implements ProductSyncPort {
  final Database db;
  ProductSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'product',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE product SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class TransactionItemSyncPortSqflite implements TransactionItemSyncPort {
  final Database db;
  TransactionItemSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'transaction_item',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE transaction_item SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class CompanySyncPortSqflite implements CompanySyncPort {
  final Database db;
  CompanySyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'company',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE company SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class CustomerSyncPortSqflite implements CustomerSyncPort {
  final Database db;
  CustomerSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'customer',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE customer SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class DebtSyncPortSqflite implements DebtSyncPort {
  final Database db;
  DebtSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'debt',
      where: _Sql.commonWhere,
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE debt SET isDirty = 0, syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class StockLevelSyncPortSqflite implements StockLevelSyncPort {
  final Database db;
  StockLevelSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'stock_level',
      where: 'syncAt IS NULL',
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<int> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE stock_level SET syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}

class StockMovementSyncPortSqflite implements StockMovementSyncPort {
  final Database db;
  StockMovementSyncPortSqflite(this.db);

  @override
  Future<List<Map<String, Object?>>> findDirty({int limit = 200}) {
    return db.query(
      'stock_movement',
      where: 'syncAt IS NULL',
      orderBy: _Sql.order,
      limit: limit,
    );
  }

  @override
  Future<void> markSynced(Iterable<int> ids, DateTime at) async {
    if (ids.isEmpty) return;
    final ts = at.toIso8601String();
    final q =
        'UPDATE stock_movement SET syncAt = ?, updatedAt = ? WHERE id IN (${_Sql.listQ(ids.length)})';
    await db.rawUpdate(q, [ts, ts, ...ids]);
  }
}
