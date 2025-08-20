/// Sqflite repository for savings goals using AppDatabase transactions.

import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/domain/goals/repositories/saving_goal_repository.dart';

class SavingGoalRepositorySqflite implements SavingGoalRepository {
  final AppDatabase db;
  SavingGoalRepositorySqflite(this.db);

  @override
  Future<List<SavingGoal>> findAll(SavingGoalQuery q) async {
    return db.tx((txn) async {
      final where = <String>[];
      final args = <Object?>[];

      where.add('deletedAt IS NULL');
      if (q.onlyActive) where.add('isArchived = 0');
      if (q.search != null && q.search!.trim().isNotEmpty) {
        where.add('(name LIKE ? OR description LIKE ?)');
        final like = '%${q.search!.trim()}%';
        args.addAll([like, like]);
      }
      if (q.completed != null) {
        if (q.completed == true) {
          where.add('savedCents >= targetCents AND targetCents > 0');
        } else {
          where.add('NOT (savedCents >= targetCents AND targetCents > 0)');
        }
      }

      final sql = StringBuffer()
        ..write('SELECT * FROM saving_goal ')
        ..write('WHERE ${where.join(" AND ")} ')
        ..write('ORDER BY updatedAt DESC ');
      if (q.limit != null) {
        sql.write('LIMIT ${q.limit}');
        if (q.offset != null) sql.write(' OFFSET ${q.offset}');
      }

      final rows = await txn.rawQuery(sql.toString(), args);
      return rows.map((e) => SavingGoal.fromMap(e)).toList();
    });
  }

  @override
  Future<int> count(SavingGoalQuery q) async {
    return db.tx((txn) async {
      final where = <String>[];
      final args = <Object?>[];

      where.add('deletedAt IS NULL');
      if (q.onlyActive) where.add('isArchived = 0');
      if (q.search != null && q.search!.trim().isNotEmpty) {
        where.add('(name LIKE ? OR description LIKE ?)');
        final like = '%${q.search!.trim()}%';
        args.addAll([like, like]);
      }
      if (q.completed != null) {
        if (q.completed == true) {
          where.add('savedCents >= targetCents AND targetCents > 0');
        } else {
          where.add('NOT (savedCents >= targetCents AND targetCents > 0)');
        }
      }

      final sql =
          'SELECT COUNT(*) as c FROM saving_goal WHERE ${where.join(" AND ")}';
      final row = await txn.rawQuery(sql, args);
      final v = row.first['c'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    });
  }

  @override
  Future<SavingGoal?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'saving_goal',
        where: 'id = ? AND deletedAt IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SavingGoal.fromMap(rows.first);
    });
  }

  @override
  Future<void> insert(SavingGoal e) async {
    await db.tx((txn) async {
      await txn.insert(
        'saving_goal',
        e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> update(SavingGoal e) async {
    await db.tx((txn) async {
      await txn.update(
        'saving_goal',
        e.toMap(),
        where: 'id = ?',
        whereArgs: [e.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> updatePartial(String id, Map<String, Object?> patch) async {
    await db.tx((txn) async {
      await txn.update(
        'saving_goal',
        patch,
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await db.tx((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'saving_goal',
        {'deletedAt': now, 'updatedAt': now, 'isDirty': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> hardDelete(String id) async {
    await db.tx((txn) async {
      await txn.delete('saving_goal', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> addToSaved(String id, int deltaCents) async {
    await db.tx((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.rawUpdate(
        '''
        UPDATE saving_goal
        SET savedCents = MAX(0, savedCents + ?), updatedAt = ?, isDirty = 1
        WHERE id = ? AND deletedAt IS NULL
        ''',
        [deltaCents, now, id],
      );
    });
  }
}
