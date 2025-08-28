// Helpers to stamp default account on rows when missing.
import 'package:sqflite/sqflite.dart';

Future<String?> findDefaultAccountId(DatabaseExecutor db) async {
  final rows = await db.query(
    'account',
    columns: ['id'],
    where: 'isDefault = 1 AND deletedAt IS NULL',
    orderBy: 'updatedAt DESC',
    limit: 1,
  );
  if (rows.isNotEmpty) return rows.first['id']?.toString();

  final any = await db.query(
    'account',
    columns: ['id'],
    where: 'deletedAt IS NULL',
    orderBy: 'updatedAt DESC',
    limit: 1,
  );
  if (any.isNotEmpty) return any.first['id']?.toString();

  return null;
}

Future<Map<String, Object?>> stampAccountIfMissing(
  DatabaseExecutor db, {
  required Map<String, Object?> values,
  String column = 'account',
  String? preferredAccountId,
}) async {
  final v = Map<String, Object?>.from(values);
  final cur = (v[column] ?? '').toString();
  if (cur.isNotEmpty) return v;

  final resolved = preferredAccountId ?? await findDefaultAccountId(db);
  if (resolved != null && resolved.isNotEmpty) v[column] = resolved;
  return v;
}
