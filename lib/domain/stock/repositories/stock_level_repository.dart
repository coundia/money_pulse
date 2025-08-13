// Repository contract for StockLevel persistence and queries

import '../entities/stock_level.dart';

class StockLevelRow {
  final String id;
  final String productLabel;
  final String companyLabel;
  final int stockOnHand;
  final int stockAllocated;
  final DateTime updatedAt;

  StockLevelRow({
    required this.id,
    required this.productLabel,
    required this.companyLabel,
    required this.stockOnHand,
    required this.stockAllocated,
    required this.updatedAt,
  });
}

abstract class StockLevelRepository {
  Future<List<StockLevelRow>> search({String query = ''});
  Future<StockLevel?> findById(String id);
  Future<int> create(StockLevel level);
  Future<void> update(StockLevel level);
  Future<void> delete(String id);

  Future<List<Map<String, Object?>>> listProductVariants({String query = ''});
  Future<List<Map<String, Object?>>> listCompanies({String query = ''});
}
