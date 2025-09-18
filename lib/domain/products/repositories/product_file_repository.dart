// Repository contract for product_file persistence.
import 'package:money_pulse/domain/products/entities/product_file.dart';

abstract class ProductFileRepository {
  Future<void> create(ProductFile file);
  Future<void> createMany(List<ProductFile> files);
  Future<List<ProductFile>> findByProduct(String productId);
}
