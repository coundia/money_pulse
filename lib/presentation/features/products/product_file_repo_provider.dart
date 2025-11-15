// Riverpod provider for product file repository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/products/repositories/product_file_repository.dart';
import 'package:jaayko/infrastructure/repositories/product_file_repository_sqflite.dart';
import 'package:jaayko/presentation/app/providers.dart';

final productFileRepoProvider = Provider<ProductFileRepository>((ref) {
  final db = ref.read(dbProvider).db;
  return ProductFileRepositorySqflite(db);
});
