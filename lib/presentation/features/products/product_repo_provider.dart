import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/domain/products/repositories/product_repository.dart';
import 'package:jaayko/infrastructure/repositories/product_repository_sqflite.dart';

final productRepoProvider = Provider<ProductRepository>((ref) {
  final db = ref.read(dbProvider);
  return ProductRepositorySqflite(db);
});
