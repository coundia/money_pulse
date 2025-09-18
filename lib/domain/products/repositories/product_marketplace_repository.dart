// Contract to push products with images to marketplace
import 'dart:io';
import 'package:money_pulse/domain/products/entities/product.dart';

abstract class ProductMarketplaceRepository {
  Future<void> pushToMarketplace(Product product, List<File> images);
}
