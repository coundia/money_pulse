import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';

class CompanyRepositorySqflite implements CompanyRepository {
  final AppDatabase db;
  CompanyRepositorySqflite(this.db);

  String _nowIso() => DateTime.now().toIso8601String();

  // --- Default normalization -----------------------------------------------
  /// Ensures there is exactly one default company (among non-deleted rows).
  /// If [preferId] is provided and exists, that one wins; otherwise the
  /// most recently updated default (if any), else most recently updated row.
  Future<void> _normalizeDefault(DatabaseExecutor e, {String? preferId}) async {
    // If no companies, nothing to do.
    final any = await e.query(
      'company',
      columns: ['id'],
      where: 'deletedAt IS NULL',
      limit: 1,
    );
    if (any.isEmpty) return;

    String? targetId = preferId;

    // If no explicit preference, choose currently-default (most recent) if any.
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

    // If still none, choose most recently updated active company.
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

    // Unset default for all other defaults.
    final others = await e.query(
      'company',
      columns: ['id'],
      where: 'isDefault=1 AND id<>? AND deletedAt IS NULL',
      whereArgs: [targetId],
    );

    if (others.isEmpty) {
      // Nothing to unset; ensure target is marked default at least.
      await e.rawUpdate(
        'UPDATE company SET isDefault=1 WHERE id=? AND isDefault<>1',
        [targetId],
      );
      return;
    }

    final nowIso = _nowIso();
    // unset others
    final otherIds = others.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(
      otherIds.length,
      '?',
    ).join(','); // "?, ?, ?"
    await e.rawUpdate(
      'UPDATE company '
      'SET isDefault=0, isDirty=1, version=COALESCE(version,0)+1, updatedAt=? '
      'WHERE id IN ($placeholders)',
      [nowIso, ...otherIds],
    );

    // make target default (idempotent)
    await e.rawUpdate(
      'UPDATE company '
      'SET isDefault=1, isDirty=1, version=COALESCE(version,0)+1, updatedAt=? '
      'WHERE id=? AND isDefault<>1',
      [nowIso, targetId],
    );

    // best-effort change_log for target + others
    final uuid = const Uuid();
    // target
    await e.rawInsert(
      'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
      'VALUES(?,?,?,?,?,?,?,?) '
      'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
      'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
      [
        uuid.v4(),
        'company',
        targetId,
        'UPDATE',
        null,
        'PENDING',
        nowIso,
        nowIso,
      ],
    );
    // others
    for (final oid in otherIds) {
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [uuid.v4(), 'company', oid, 'UPDATE', null, 'PENDING', nowIso, nowIso],
      );
    }
  }
  // -------------------------------------------------------------------------

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
      // Normalize before returning default.
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
      // Only normalize on "full" lists (no search). We still honor onlyActive.
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
        orderBy: 'name COLLATE NOCASE ASC',
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
    final now = DateTime.now();
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

      // change_log for INSERT
      final idLog = const Uuid().v4();
      final nowIso = _nowIso();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'company', id, 'INSERT', null, 'PENDING', nowIso, nowIso],
      );

      // If caller tried to set default on create OR there is no default yet,
      // normalize to end up with exactly one default (prefer the newly created).
      await _normalizeDefault(
        txn,
        preferId: data['isDefault'] == 1 ? id : null,
      );
    });

    return id;
  }

  @override
  Future<void> update(Company c) async {
    final now = DateTime.now();
    final next = c.copyWith(
      updatedAt: now,
      isDirty: true,
      version: c.version + 1,
    );
    await db.tx((txn) async {
      await txn.update(
        'company',
        next.toMap(),
        where: 'id=?',
        whereArgs: [c.id],
      );

      // change_log for UPDATE
      final idLog = const Uuid().v4();
      final nowIso = _nowIso();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'company', c.id, 'UPDATE', null, 'PENDING', nowIso, nowIso],
      );

      // If this update toggled default, or we end up with 0/2+ defaults, fix it.
      await _normalizeDefault(txn, preferId: next.isDefault ? next.id : null);
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
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
      );

      // After deleting, ensure another one is default (if needed).
      await _normalizeDefault(txn);
    });
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now();
    await db.tx((txn) async {
      await txn.update(
        'company',
        {'deletedAt': null, 'updatedAt': now.toIso8601String(), 'isDirty': 1},
        where: 'id=?',
        whereArgs: [id],
      );

      // After restore, normalize (no preference).
      await _normalizeDefault(txn);
    });
  }
}
