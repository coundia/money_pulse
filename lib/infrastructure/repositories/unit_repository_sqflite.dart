import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/units/entities/unit.dart';
import 'package:money_pulse/domain/units/repositories/unit_repository.dart';

class UnitRepositorySqflite implements UnitRepository {
  final AppDatabase _db;
  UnitRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  @override
  Future<Unit> create(Unit unit) async {
    final u = unit.copyWith(updatedAt: DateTime.now(), version: 0, isDirty: 1);

    await _db.tx((txn) async {
      await txn.insert(
        'unit',
        u.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // change_log
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'unit', u.id, 'INSERT', null, 'PENDING', _now(), _now()],
      );
    });

    return u;
  }

  @override
  Future<void> update(Unit unit) async {
    final u = unit.copyWith(
      updatedAt: DateTime.now(),
      version: unit.version + 1,
      isDirty: 1,
    );

    await _db.tx((txn) async {
      await txn.update(
        'unit',
        u.toMap(),
        where: 'id=?',
        whereArgs: [u.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'unit', u.id, 'UPDATE', null, 'PENDING', _now(), _now()],
      );
    });
  }

  @override
  Future<Unit?> findById(String id) async {
    final rows = await _db.db.query(
      'unit',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Unit.fromMap(rows.first);
  }

  @override
  Future<Unit?> findByCode(String code) async {
    final rows = await _db.db.query(
      'unit',
      where: 'code=? AND (deletedAt IS NULL)',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Unit.fromMap(rows.first);
  }

  @override
  Future<List<Unit>> findAllActive() async {
    final rows = await _db.db.query(
      'unit',
      where: 'deletedAt IS NULL',
      orderBy: 'code COLLATE NOCASE ASC',
    );
    return rows.map(Unit.fromMap).toList();
  }

  @override
  Future<List<Unit>> searchActive(String query, {int limit = 200}) async {
    final q = '%${query.trim()}%';
    final rows = await _db.db.query(
      'unit',
      where:
          '(deletedAt IS NULL) AND (code LIKE ? OR name LIKE ? OR description LIKE ?)',
      whereArgs: [q, q, q],
      orderBy: 'code COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(Unit.fromMap).toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _now();
    await _db.tx((txn) async {
      await txn.rawUpdate(
        'UPDATE unit SET deletedAt=?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [now, now, id],
      );

      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'unit', id, 'DELETE', null, 'PENDING', now, now],
      );
    });
  }
}
