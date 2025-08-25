/* Lookup helpers to resolve remote/local ids using sqflite with developer logs for diagnostics. */
import 'package:sqflite/sqflite.dart';

Future<String?> remoteIdOfDb(Database db, String table, String? id) async {
  print('[remoteIdOfDb] table=$table id=$id');
  if (id == null) {
    print('[remoteIdOfDb] table=$table -> id is null');
    return null;
  }
  final rows = await db.query(
    table,
    columns: ['id', 'remoteId'],
    where: 'id = ? OR remoteId = ? OR localId = ?',
    whereArgs: [id, id, id],
  );
  if (rows.isEmpty) {
    print('[remoteIdOfDb] table=$table id=$id -> no row');
    return null;
  }
  final v = rows.first['remoteId'];

  print(rows);

  print('[remoteIdOfDb] table=$table id=$id -> remoteId=$v');
  return v == null ? null : v.toString();
}

Future<String?> localIdOfDb(Database db, String table, String? id) async {
  print('[localIdOfDb] table=$table id=$id');
  if (id == null) {
    print('[localIdOfDb] table=$table -> id is null');
    return null;
  }
  final rows = await db.query(
    table,
    columns: ['id', 'localId', 'remoteId'],
    where: 'id = ? OR remoteId = ? OR localId = ?',
    whereArgs: [id, id, id],
    limit: 1,
  );
  if (rows.isEmpty) {
    print('[localIdOfDb] table=$table id=$id -> no row');
    return null;
  }
  final local = rows.first['localId']?.toString();
  final primary = rows.first['id']?.toString();
  final result = (local != null && local.isNotEmpty) ? local : primary;
  print('[localIdOfDb] table=$table id=$id -> localId=$result');
  return result;
}
