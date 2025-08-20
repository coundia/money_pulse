import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase I = AppDatabase._();

  static const _dbFile = 'money_pulse.db';

  Database? _db;

  Future<void> init({int version = 1}) async {
    if (_db != null) return;
    final path = await _resolvePath();
    _db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) async {
        await _applySchema(db);
      },
    );
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError(
        'AppDatabase not initialized. Call AppDatabase.I.init() first.',
      );
    }
    return d;
  }

  Future<void> close() async {
    final d = _db;
    if (d != null) {
      await d.close();
      _db = null;
    }
  }

  Future<T> tx<T>(Future<T> Function(Transaction) action) async {
    return await db.transaction<T>((txn) async => await action(txn));
  }

  Future<void> recreate({int version = 1}) async {
    final path = await _resolvePath();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    await deleteDatabase(path);
    _db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) async {
        await _applySchema(db);
      },
    );
  }

  Future<void> deleteOnly() async {
    final path = await _resolvePath();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    await deleteDatabase(path);
  }

  Future<bool> exists() async {
    final path = await _resolvePath();
    return databaseExists(path);
  }

  Future<String> _resolvePath() async {
    final base = await getDatabasesPath();
    return p.join(base, _dbFile);
  }

  Future<void> _applySchema(Database db) async {
    final raw = await rootBundle.loadString('assets/db/schema_v1.sql');
    final statements = raw
        .split(RegExp(r';\s*(?:\n|$)'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final batch = db.batch();
    for (final s in statements) {
      batch.execute(s);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upgradeSchemas() async {}
}
