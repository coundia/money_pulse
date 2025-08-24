// lib/sync/infrastructure/sqflite_sync_ports.dart (extraits)
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

import '../application/_ports.dart';

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
