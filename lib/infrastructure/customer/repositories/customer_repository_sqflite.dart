// Sqflite implementation with hasOpenDebt filter and updatedAt DESC ordering.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';

class CustomerRepositorySqflite implements CustomerRepository {
  final AppDatabase db;
  CustomerRepositorySqflite(this.db);

  @override
  Future<Customer?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'customer',
        where: 'id=?',
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
        where.add(
          '(fullName LIKE ? OR phone LIKE ? OR email LIKE ? OR code LIKE ?)',
        );
        final v = '%${q.search!.trim()}%';
        args.addAll([v, v, v, v]);
      }

      // hasOpenDebt filter via EXISTS
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
          ? 'updatedAt DESC'
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
        where.add(
          '(fullName LIKE ? OR phone LIKE ? OR email LIKE ? OR code LIKE ?)',
        );
        final v = '%${q.search!.trim()}%';
        args.addAll([v, v, v, v]);
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
        'SELECT COUNT(*) AS c FROM customer ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}',
        args,
      );
      final v = res.first['c'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    });
  }

  @override
  Future<String> create(Customer c) async {
    final now = DateTime.now();
    final id = c.id.isNotEmpty ? c.id : const Uuid().v4();
    final fullName = (c.fullName.trim().isEmpty)
        ? _joinName(c.firstName, c.lastName)
        : c.fullName;
    final data = c
        .copyWith(
          id: id,
          fullName: fullName,
          createdAt: c.createdAt,
          updatedAt: now,
          isDirty: true,
          version: c.version,
        )
        .toMap();

    await db.tx((txn) async {
      await txn.insert(
        'customer',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
    return id;
  }

  @override
  Future<void> update(Customer c) async {
    final now = DateTime.now();
    final fullName = (c.fullName.trim().isEmpty)
        ? _joinName(c.firstName, c.lastName)
        : c.fullName;
    final next = c.copyWith(
      fullName: fullName,
      updatedAt: now,
      isDirty: true,
      version: c.version + 1,
    );
    await db.tx((txn) async {
      await txn.update(
        'customer',
        next.toMap(),
        where: 'id=?',
        whereArgs: [c.id],
      );
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await db.tx((txn) async {
      await txn.update(
        'customer',
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
        'customer',
        {'deletedAt': null, 'updatedAt': now.toIso8601String(), 'isDirty': 1},
        where: 'id=?',
        whereArgs: [id],
      );
    });
  }

  static String _joinName(String? first, String? last) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    return [f, l].where((e) => e.isNotEmpty).join(' ').trim();
  }
}
