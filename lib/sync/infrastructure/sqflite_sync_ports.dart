// lib/sync/infrastructure/sqflite_sync_ports.dart (extraits)
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart' hide Json;
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

import '../../domain/company/entities/company.dart';
import '../../domain/customer/entities/customer.dart';
import '../../domain/transactions/entities/transaction_entry.dart';
import '../application/_ports.dart';
import '../application/_pull_ports.dart';

class AccountSyncPortSqflite implements AccountSyncPort {
  final Database db;
  AccountSyncPortSqflite(this.db);

  @override
  Future<List<Account>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      'account',
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final nowIso = at.toIso8601String();
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'account',
        {
          'isDirty': 0,
          'syncAt': nowIso,
          'updatedAt': nowIso,
          'remoteId': null == null ? null : null, // laisse tel quel
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Account?> findById(String id) async {
    final rows = await db.query(
      'account',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }
}

class CategorySyncPortSqflite implements CategorySyncPort {
  final Database db;

  String entityTable = "category";

  CategorySyncPortSqflite(this.db);

  @override
  Future<List<Category>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      'category',
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final nowIso = at.toIso8601String();
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'category',
        {'isDirty': 0, 'syncAt': nowIso, 'updatedAt': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Category?> findById(String id) async {
    final rows = await db.query(
      'category',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future upsertRemote(List<Json> items) async {}
}

class TransactionSyncPortSqflite implements TransactionSyncPort {
  final Database db;
  TransactionSyncPortSqflite(this.db);

  @override
  String get entityTable => 'transaction_entry';

  @override
  Future<List<TransactionEntry>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map((m) => TransactionEntry.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        entityTable,
        {
          'isDirty': 0,
          'syncAt': at.toIso8601String(),
          'updatedAt': at.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<TransactionEntry?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return TransactionEntry.fromMap(rows.first);
  }
}

class CustomerSyncPortSqflite implements CustomerSyncPort {
  final Database db;
  CustomerSyncPortSqflite(this.db);

  String get entityTable => 'customer';

  @override
  Future<List<Customer>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map((m) => Customer.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final batch = db.batch();
    final iso = at.toUtc().toIso8601String();
    for (final id in ids) {
      batch.update(
        entityTable,
        {'isDirty': 0, 'syncAt': iso, 'updatedAt': iso},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Customer?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }
}

class CompanySyncPortSqflite implements CompanySyncPort {
  final Database db;
  CompanySyncPortSqflite(this.db);

  String get entityTable => 'company';

  @override
  Future<List<Company>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map((m) => Company.fromMap(m)).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final batch = db.batch();
    final iso = at.toUtc().toIso8601String();
    for (final id in ids) {
      batch.update(
        entityTable,
        {'isDirty': 0, 'syncAt': iso, 'updatedAt': iso},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Company?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Company.fromMap(rows.first);
  }
}
