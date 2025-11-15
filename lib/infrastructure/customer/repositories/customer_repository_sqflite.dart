// lib/infrastructure/customer/customer_repository_sqflite.dart
//
// Customer repository refactored to use ChangeTrackedExec helpers.
// - insertTracked / updateTracked / softDeleteTracked centralize:
//   * UTC timestamps (updatedAt), isDirty=1
//   * version++ on UPDATE/DELETE
//   * change_log upsert (PENDING)
//   * optional account stamping via `account` column
// - Keeps existing query features (search, filters, paging)
//
import 'package:jaayko/sync/infrastructure/change_tracked_exec.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/customer/entities/customer.dart';
import 'package:jaayko/domain/customer/repositories/customer_repository.dart';

class CustomerRepositorySqflite implements CustomerRepository {
  final AppDatabase db;
  CustomerRepositorySqflite(this.db);

  // ---------- Reads ----------

  @override
  Future<Customer?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'customer',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Customer.fromMap(rows.first);
    });
  }

  @override
  Future<List<Customer>> findAll(CustomerQuery q) async {
    return db.tx((txn) async {
      final where = <String>[];
      final args = <Object?>[];

      if (q.onlyActive) where.add('deletedAt IS NULL');

      if ((q.companyId ?? '').isNotEmpty) {
        where.add('companyId = ?');
        args.add(q.companyId);
      }

      if ((q.search ?? '').trim().isNotEmpty) {
        final term = '%${q.search!.trim().toLowerCase()}%';
        where.add(
          '('
          'lower(COALESCE(fullName,"")) LIKE ? OR '
          'lower(COALESCE(phone,""))    LIKE ? OR '
          'lower(COALESCE(email,""))    LIKE ? OR '
          'lower(COALESCE(code,""))     LIKE ?'
          ')',
        );
        args.addAll([term, term, term, term]);
      }

      if (q.hasOpenDebt != null) {
        final existsSql = '''
          EXISTS(SELECT 1 FROM debt d
                 WHERE d.customerId = customer.id
                   AND d.deletedAt IS NULL
                   AND (d.statuses IS NULL OR d.statuses='OPEN')
                   AND COALESCE(d.balance,0) > 0)
        ''';
        where.add(q.hasOpenDebt! ? existsSql : 'NOT $existsSql');
      }

      final orderBy = q.orderByUpdatedAtDesc
          ? 'datetime(updatedAt) DESC'
          : 'fullName COLLATE NOCASE ASC';

      final rows = await txn.query(
        'customer',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: orderBy,
        limit: q.limit,
        offset: q.offset,
      );
      return rows.map(Customer.fromMap).toList();
    });
  }

  @override
  Future<int> count(CustomerQuery q) async {
    return db.tx((txn) async {
      final where = <String>[];
      final args = <Object?>[];

      if (q.onlyActive) where.add('deletedAt IS NULL');

      if ((q.companyId ?? '').isNotEmpty) {
        where.add('companyId = ?');
        args.add(q.companyId);
      }

      if ((q.search ?? '').trim().isNotEmpty) {
        final term = '%${q.search!.trim().toLowerCase()}%';
        where.add(
          '('
          'lower(COALESCE(fullName,"")) LIKE ? OR '
          'lower(COALESCE(phone,""))    LIKE ? OR '
          'lower(COALESCE(email,""))    LIKE ? OR '
          'lower(COALESCE(code,""))     LIKE ?'
          ')',
        );
        args.addAll([term, term, term, term]);
      }

      if (q.hasOpenDebt != null) {
        final existsSql = '''
          EXISTS(SELECT 1 FROM debt d
                 WHERE d.customerId = customer.id
                   AND d.deletedAt IS NULL
                   AND (d.statuses IS NULL OR d.statuses='OPEN')
                   AND COALESCE(d.balance,0) > 0)
        ''';
        where.add(q.hasOpenDebt! ? existsSql : 'NOT $existsSql');
      }

      final res = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM customer '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}',
        args,
      );
      final v = res.first['c'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    });
  }

  // ---------- Writes (ChangeTrackedExec) ----------

  @override
  Future<String> create(Customer c) async {
    final id = c.id.isNotEmpty ? c.id : const Uuid().v4();
    final fullName = c.fullName.trim().isEmpty
        ? _joinName(c.firstName, c.lastName)
        : c.fullName;

    final toInsert = c
        .copyWith(
          id: id,
          fullName: fullName,
          // createdAt may be set by entity; insertTracked will ensure updatedAt/isDirty
          version: c.version, // keep as provided (often 0)
          isDirty: true,
        )
        .toMap();

    await db.tx((txn) async {
      await txn.insertTracked(
        'customer',
        toInsert,
        operation: 'INSERT',
        // accountColumn: 'account' (default) — column exists in schema
        // preferredAccountId / createdBy can be passed if you have them
      );
    });
    return id;
  }

  @override
  Future<void> update(Customer c) async {
    final fullName = c.fullName.trim().isEmpty
        ? _joinName(c.firstName, c.lastName)
        : c.fullName;

    final toUpdate = c.copyWith(
      fullName: fullName,
      isDirty: true, // updateTracked will keep it 1
      // version++ is handled in updateTracked
    );

    await db.tx((txn) async {
      await txn.updateTracked(
        'customer',
        toUpdate.toMap(),
        where: 'id = ?',
        whereArgs: [c.id],
        entityId: c.id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final when = (at ?? DateTime.now()).toUtc().toIso8601String();
    await db.tx((txn) async {
      // softDeleteTracked stamps updatedAt/isDirty, bumps version, writes change_log
      await txn.softDeleteTracked('customer', entityId: id);
      // If you want to force a specific timestamp, you can follow-up with updateTracked:
      await txn.updateTracked(
        'customer',
        {'updatedAt': when},
        where: 'id = ?',
        whereArgs: [id],
        entityId: id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> restore(String id) async {
    await db.tx((txn) async {
      await txn.updateTracked(
        'customer',
        {
          'deletedAt': null,
          // updatedAt/isDirty handled inside updateTracked
        },
        where: 'id = ?',
        whereArgs: [id],
        entityId: id,
        operation: 'UPDATE',
      );
    });
  }

  // ---------- Helpers ----------

  static String _joinName(String? first, String? last) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    return [f, l].where((e) => e.isNotEmpty).join(' ').trim();
  }
}
