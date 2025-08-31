// Sqflite repository for Company with default normalization, UTC stamping, safe updates (no PK change), and change_log strict insert with try/catch.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';
import 'package:money_pulse/sync/infrastructure/change_log_helper.dart';

class CompanyRepositorySqflite implements CompanyRepository {
  final AppDatabase db;
  CompanyRepositorySqflite(this.db);

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  Future<void> _tryLogPending(
    DatabaseExecutor e, {
    required String entityId,
    required String operation,
    String? accountId,
    String? createdBy,
  }) async {
    try {
      await upsertChangeLogPending(
        e,
        entityTable: 'company',
        entityId: entityId,
        operation: operation,
        accountId: accountId,
        createdBy: createdBy,
      );
    } on DatabaseException catch (_) {}
  }

  Future<void> _normalizeDefault(DatabaseExecutor e, {String? preferId}) async {
    final any = await e.query(
      'company',
      columns: ['id'],
      where: 'deletedAt IS NULL',
      limit: 1,
    );
    if (any.isEmpty) return;

    String? targetId = preferId;

    if (targetId == null) {
      final currentDefault = await e.query(
        'company',
        columns: ['id'],
        where: 'isDefault=1 AND deletedAt IS NULL',
        orderBy: 'updatedAt DESC',
        limit: 1,
      );
      if (currentDefault.isNotEmpty) {
        targetId = currentDefault.first['id'] as String;
      }
    }

    if (targetId == null) {
      final newest = await e.query(
        'company',
        columns: ['id'],
        where: 'deletedAt IS NULL',
        orderBy: 'updatedAt DESC',
        limit: 1,
      );
      if (newest.isEmpty) return;
      targetId = newest.first['id'] as String;
    }

    final others = await e.query(
      'company',
      columns: ['id'],
      where: 'isDefault=1 AND id<>? AND deletedAt IS NULL',
      whereArgs: [targetId],
    );

    if (others.isEmpty) {
      await e.rawUpdate(
        'UPDATE company SET isDefault=1 WHERE id=? AND isDefault<>1',
        [targetId],
      );
      await _tryLogPending(e, entityId: targetId, operation: 'UPDATE');
      return;
    }

    final nowIso = _nowIso();
    final otherIds = others.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(otherIds.length, '?').join(',');

    await e.rawUpdate(
      'UPDATE company '
      'SET isDefault=0, isDirty=1, version=COALESCE(version,0)+1, updatedAt=? '
      'WHERE id IN ($placeholders)',
      [nowIso, ...otherIds],
    );

    await e.rawUpdate(
      'UPDATE company '
      'SET isDefault=1, isDirty=1, version=COALESCE(version,0)+1, updatedAt=? '
      'WHERE id=? AND isDefault<>1',
      [nowIso, targetId],
    );

    await _tryLogPending(e, entityId: targetId, operation: 'UPDATE');
    for (final oid in otherIds) {
      await _tryLogPending(e, entityId: oid, operation: 'UPDATE');
    }
  }

  @override
  Future<Company?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'company',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Company.fromMap(rows.first);
    });
  }

  @override
  Future<Company?> findDefault() async {
    return db.tx((txn) async {
      await _normalizeDefault(txn);
      final rows = await txn.query(
        'company',
        where: 'isDefault=1 AND (deletedAt IS NULL)',
        orderBy: 'updatedAt DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Company.fromMap(rows.first);
    });
  }

  @override
  Future<List<Company>> findAll(CompanyQuery q) async {
    return db.tx((txn) async {
      final isUnfiltered = (q.search ?? '').trim().isEmpty;
      if (isUnfiltered) {
        await _normalizeDefault(txn);
      }

      final where = <String>[];
      final args = <Object?>[];

      if (q.onlyActive) where.add('deletedAt IS NULL');

      if ((q.search ?? '').trim().isNotEmpty) {
        where.add(
          '(code LIKE ? OR name LIKE ? OR phone LIKE ? OR email LIKE ?)',
        );
        final v = '%${q.search!.trim()}%';
        args.addAll([v, v, v, v]);
      }

      final rows = await txn.query(
        'company',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'updatedAt DESC',
        limit: q.limit,
        offset: q.offset,
      );
      return rows.map(Company.fromMap).toList();
    });
  }

  @override
  Future<int> count(CompanyQuery q) async {
    return db.tx((txn) async {
      final where = <String>[];
      final args = <Object?>[];

      if (q.onlyActive) where.add('deletedAt IS NULL');
      if ((q.search ?? '').trim().isNotEmpty) {
        where.add(
          '(code LIKE ? OR name LIKE ? OR phone LIKE ? OR email LIKE ?)',
        );
        final v = '%${q.search!.trim()}%';
        args.addAll([v, v, v, v]);
      }

      final res = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM company ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}',
        args,
      );
      return (res.first['c'] as int?) ?? 0;
    });
  }

  @override
  Future<String> create(Company c) async {
    final now = DateTime.now().toUtc();
    final id = c.id.isNotEmpty ? c.id : const Uuid().v4();
    final data = c
        .copyWith(
          id: id,
          createdAt: c.createdAt,
          updatedAt: now,
          isDirty: true,
          version: c.version,
        )
        .toMap();

    await db.tx((txn) async {
      await txn.insert(
        'company',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _tryLogPending(txn, entityId: id, operation: 'INSERT');

      await _normalizeDefault(
        txn,
        preferId: data['isDefault'] == 1 ? id : null,
      );
    });

    return id;
  }

  @override
  Future<void> update(Company c) async {
    final now = DateTime.now().toUtc();
    final next = c.copyWith(
      updatedAt: now,
      isDirty: true,
      version: c.version + 1,
    );

    await db.tx((txn) async {
      final map = next.toMap()..remove('id');

      await txn.update(
        'company',
        map,
        where: 'id=?',
        whereArgs: [c.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _tryLogPending(txn, entityId: c.id, operation: 'UPDATE');

      await _normalizeDefault(txn, preferId: next.isDefault ? next.id : null);
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final now = (at ?? DateTime.now()).toUtc();
    await db.tx((txn) async {
      await txn.update(
        'company',
        {
          'deletedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
        },
        where: 'id=?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _tryLogPending(txn, entityId: id, operation: 'DELETE');

      await _normalizeDefault(txn);
    });
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now().toUtc();
    await db.tx((txn) async {
      await txn.update(
        'company',
        {'deletedAt': null, 'updatedAt': now.toIso8601String(), 'isDirty': 1},
        where: 'id=?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _tryLogPending(txn, entityId: id, operation: 'UPDATE');

      await _normalizeDefault(txn);
    });
  }
}
