/// Repository contract for StockMovement persistence and queries.
import '../entities/stock_movement.dart';

class StockMovementRow {
  final String id;
  final String productLabel;
  final String companyLabel;
  final String type;
  final int quantity;
  final DateTime createdAt;

  StockMovementRow({
    required this.id,
    required this.productLabel,
    required this.companyLabel,
    required this.type,
    required this.quantity,
    required this.createdAt,
  });
}

abstract class StockMovementRepository {
  Future<List<StockMovementRow>> search({String query = ''});
  Future<StockMovement?> findById(String id);
  Future<int> create(StockMovement m);
  Future<void> update(StockMovement m);
  Future<void> delete(String id);

  Future<List<Map<String, Object?>>> listProductVariants({String query = ''});
  Future<List<Map<String, Object?>>> listCompanies({String query = ''});
}
