// lib/sync/infrastructure/sqflite_sync_ports.dart (extraits)
import 'package:jaayko/sync/infrastructure/sync_api_client.dart' hide Json;
import 'package:sqflite/sqflite.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/domain/categories/entities/category.dart';

import '../../domain/accounts/entities/account_user.dart';
import '../../domain/company/entities/company.dart';
import '../../domain/customer/entities/customer.dart';
import '../../domain/debts/entities/debt.dart';
import '../../domain/products/entities/product.dart';
import '../../domain/stock/entities/stock_level.dart';
import '../../domain/stock/entities/stock_movement.dart';
import '../../domain/transactions/entities/transaction_entry.dart';
import '../../domain/transactions/entities/transaction_item.dart';
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

class ProductSyncPortSqflite implements ProductSyncPort {
  final Database db;
  ProductSyncPortSqflite(this.db);

  String get entityTable => 'product';

  @override
  Future<List<Product>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<Product?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }
}

class TransactionItemSyncPortSqflite implements TransactionItemSyncPort {
  final Database db;
  TransactionItemSyncPortSqflite(this.db);

  String get entityTable => 'transaction_item';

  @override
  Future<List<TransactionItem>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(TransactionItem.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<TransactionItem?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionItem.fromMap(rows.first);
  }
}

class StockLevelSyncPortSqflite implements StockLevelSyncPort {
  final Database db;
  StockLevelSyncPortSqflite(this.db);

  String get entityTable => 'stock_level';

  @override
  Future<List<StockLevel>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1', // supprimé "deletedAt IS NULL" car pas de champ
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(StockLevel.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<StockLevel?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StockLevel.fromMap(rows.first);
  }
}

class StockMovementSyncPortSqflite implements StockMovementSyncPort {
  final Database db;
  StockMovementSyncPortSqflite(this.db);

  String get entityTable => 'stock_movement';

  @override
  Future<List<StockMovement>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<StockMovement?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StockMovement.fromMap(rows.first);
  }
}

class DebtSyncPortSqflite implements DebtSyncPort {
  final Database db;
  DebtSyncPortSqflite(this.db);

  String get entityTable => 'debt';

  @override
  Future<List<Debt>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(Debt.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<Debt?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Debt.fromMap(rows.first);
  }
}

class AccountUserSyncPortSqflite implements AccountUserSyncPort {
  final Database db;
  AccountUserSyncPortSqflite(this.db);

  String get entityTable => 'account_users';

  @override
  Future<List<AccountUser>> findDirty({int limit = 200}) async {
    final rows = await db.query(
      entityTable,
      where: 'isDirty = 1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(AccountUser.fromMap).toList();
  }

  @override
  Future<void> markSynced(Iterable<String> ids, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    final batch = db.batch();
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
  Future<AccountUser?> findById(String id) async {
    final rows = await db.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    if (rows.first['account'] == null) return null;
    return AccountUser.fromMap(rows.first);
  }
}
