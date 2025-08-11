import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

class CategoryRepositorySqflite implements CategoryRepository {
  final AppDatabase _db;
  CategoryRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  @override
  Future<Category> create(Category category) async {
    final c = category.copyWith(
      updatedAt: DateTime.now(),
      version: 0,
      isDirty: true,
      typeEntry: category.typeEntry.toUpperCase(),
    );
    await _db.tx((txn) async {
      await txn.insert(
        'category',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'category', c.id, 'INSERT', null, 'PENDING', _now(), _now()],
      );
    });
    return c;
  }

  @override
  Future<void> update(Category category) async {
    final c = category.copyWith(
      updatedAt: DateTime.now(),
      version: category.version + 1,
      isDirty: true,
      typeEntry: category.typeEntry.toUpperCase(),
    );
    await _db.tx((txn) async {
      await txn.update(
        'category',
        c.toMap(),
        where: 'id=?',
        whereArgs: [c.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'category', c.id, 'UPDATE', null, 'PENDING', _now(), _now()],
      );
    });
  }

  @override
  Future<Category?> findById(String id) async {
    final r = await _db.db.query(
      'category',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return Category.fromMap(r.first);
  }

  @override
  Future<Category?> findByCode(String code) async {
    final r = await _db.db.query(
      'category',
      where: 'code=? AND deletedAt IS NULL',
      whereArgs: [code],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return Category.fromMap(r.first);
  }

  @override
  Future<List<Category>> findAllActive() async {
    final rows = await _db.db.query(
      'category',
      where: 'deletedAt IS NULL',
      orderBy: 'code ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _now();
    await _db.tx((txn) async {
      await txn.rawUpdate(
        'UPDATE category SET deletedAt=?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [now, now, id],
      );
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'category', id, 'DELETE', null, 'PENDING', now, now],
      );
    });
  }
}
