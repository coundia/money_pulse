import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase I = AppDatabase._();
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final base = await getDatabasesPath();
    final path = p.join(base, 'money_pulse.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
    return await db.transaction<T>((txn) async {
      return await action(txn);
    });
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
}
