import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';
import 'package:money_pulse/infrastructure/repositories/product_repository_sqflite.dart';

final productRepoProvider = Provider<ProductRepository>((ref) {
  final db = ref.read(dbProvider);
  return ProductRepositorySqflite(db);
});
