/// Repository contract for StockMovement persistence and rich rows with amounts.
import '../entities/stock_movement.dart';

class StockMovementRow {
  final String id;
  final String productLabel;
  final String companyLabel;
  final String type;
  final int quantity;
  final int unitPriceCents;
  final int totalCents;
  final DateTime createdAt;
  final String? orderLineId;

  StockMovementRow({
    required this.id,
    required this.productLabel,
    required this.companyLabel,
    required this.type,
    required this.quantity,
    required this.unitPriceCents,
    required this.totalCents,
    required this.createdAt,
    required this.orderLineId,
  });
}

abstract class StockMovementRepository {
  Future<List<StockMovementRow>> search({String query = ''});
  Future<StockMovement?> findById(String id);
  Future<StockMovementRow?> findRowById(String id);
  Future<int> create(StockMovement m);
  Future<void> update(StockMovement m);
  Future<void> delete(String id);

  /// Each map should at least include: {id, label, defaultPrice}
  Future<List<Map<String, Object?>>> listProductVariants({String query = ''});

  /// Each map should at least include: {id, label}
  Future<List<Map<String, Object?>>> listCompanies({String query = ''});
}
