/* Helpers to resolve remote and local ids for any table; Database and AppDatabase variants, plus company-specific helpers. */
import 'package:sqflite/sqflite.dart';

Future<String?> remoteIdOfDb(Database db, String table, String? id) async {
  if (id == null) {
    return null;
  }
  final rows = await db.query(
    table,
    columns: ['remoteId'],
    where: 'id = ? OR remoteId = ? OR localId = ?',
    whereArgs: [id, id, id],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final v = rows.first['remoteId'];
  return v == null ? null : v.toString();
}

Future<String?> localIdOfDb(Database db, String table, String? id) async {
  if (id == null) {
    return null;
  }

  final rows = await db.query(
    table,
    columns: ['id', 'localId', 'remoteId'],
    where: 'id = ? OR remoteId = ? OR localId = ?',
    whereArgs: [id, id, id],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final local = rows.first['localId']?.toString();
  final primary = rows.first['id']?.toString();
  return (local != null && local.isNotEmpty) ? local : primary;
}
