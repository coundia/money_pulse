/* Pushes dirty stock movements then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/stock_movement_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushStockMovementsUseCase implements PushPort {
  final StockMovementSyncPort port;
  final SyncApiClient api;

  PushStockMovementsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final rows = await port.findDirty(limit: batchSize);
      if (rows.isEmpty) break;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final deltas = rows.map((m) {
        return StockMovementDeltaDto(
          id: m['id'] as int?,
          type: 'UPDATE',
          typeStockMovement: m['type_stock_movement'] as String?,
          quantity: (m['quantity'] as int?) ?? 0,
          companyId: m['companyId'] as String?,
          productVariantId: m['productVariantId'] as String?,
          orderLineId: m['orderLineId'] as String?,
          discriminator: m['discriminator'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postStockMovementDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(
          'StockMovement sync failed with status ${res.statusCode}',
        );
      }
      await port.markSynced(rows.map((e) => e['id'] as int), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
