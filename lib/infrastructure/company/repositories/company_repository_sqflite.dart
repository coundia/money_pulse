import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';

class CompanyRepositorySqflite implements CompanyRepository {
  final AppDatabase db;
  CompanyRepositorySqflite(this.db);

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
      final rows = await txn.query(
        'company',
        where: 'isDefault=1 AND (deletedAt IS NULL)',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Company.fromMap(rows.first);
    });
  }

  @override
  Future<List<Company>> findAll(CompanyQuery q) async {
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

      final idLog = const Uuid().v4();
      String now = DateTime.now().toIso8601String();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'company', c.id, 'INSERT', null, 'PENDING', now, now],
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

      final idLog = const Uuid().v4();
      String now = DateTime.now().toIso8601String();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'company', c.id, 'UPDATE', null, 'PENDING', now, now],
      );
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
    });
  }
}
