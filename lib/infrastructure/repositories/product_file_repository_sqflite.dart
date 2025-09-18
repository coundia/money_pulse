// Sqflite implementation for product_file repository.
import 'package:money_pulse/domain/products/entities/product_file.dart';
import 'package:money_pulse/domain/products/repositories/product_file_repository.dart';
import 'package:sqflite/sqflite.dart';

class ProductFileRepositorySqflite implements ProductFileRepository {
  final Database db;
  ProductFileRepositorySqflite(this.db);

  @override
  Future<void> create(ProductFile file) async {
    await db.insert(
      'product_file',
      file.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> createMany(List<ProductFile> files) async {
    await db.transaction((txn) async {
      for (final f in files) {
        await txn.insert(
          'product_file',
          f.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<ProductFile>> findByProduct(String productId) async {
    final rows = await db.query(
      'product_file',
      where: 'productId = ? ',
      whereArgs: [productId],
    );
    DateTime? p(String? s) =>
        (s == null || s.isEmpty) ? null : DateTime.parse(s);
    return rows.map((e) {
      return ProductFile(
        id: e['id'] as String,
        productId: e['productId'] as String,
        remoteId: e['remoteId'] as String?,
        localId: e['localId'] as String?,
        fileName: e['fileName'] as String,
        mimeType: e['mimeType'] as String?,
        filePath: e['filePath'] as String?,
        fileSize: e['fileSize'] as int?,
        isDefault: (e['isDefault'] as int?) ?? 0,
        createdAt: p(e['createdAt'] as String?) ?? DateTime.now(),
        updatedAt: p(e['updatedAt'] as String?) ?? DateTime.now(),
        deletedAt: p(e['deletedAt'] as String?),
        syncAt: p(e['syncAt'] as String?),
        createdBy: e['createdBy'] as String?,
        version: (e['version'] as int?) ?? 0,
        isDirty: (e['isDirty'] as int?) ?? 1,
      );
    }).toList();
  }
}
