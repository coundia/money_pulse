import 'package:jaayko/domain/products/entities/product.dart';

abstract class ProductRepository {
  Future<Product> create(Product product);
  Future<void> update(Product product);
  Future<void> softDelete(String id);

  Future<Product?> findById(String id);
  Future<Product?> findByCode(String code);

  Future<List<Product>> findAllActive();
  Future<List<Product>> searchActive(String query, {int limit = 200});
}
