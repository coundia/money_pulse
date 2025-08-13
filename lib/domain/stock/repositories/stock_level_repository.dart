/// Repository contract for StockLevel CRUD, search and stock adjustments (with movement logs).
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

  /// Increment/decrement stockOnHand and insert an ADJUST movement.
  Future<void> adjustOnHandBy({
    required String productVariantId,
    required String companyId,
    required int delta,
    String? orderLineId,
    String? reason, // stored in discriminator if provided
  });

  /// Set stockOnHand to a target value by computing delta, then ADJUST.
  Future<void> adjustOnHandTo({
    required String productVariantId,
    required String companyId,
    required int target,
    String? orderLineId,
    String? reason,
  });

  Future<List<Map<String, Object?>>> listProductVariants({String query = ''});
  Future<List<Map<String, Object?>>> listCompanies({String query = ''});
}
