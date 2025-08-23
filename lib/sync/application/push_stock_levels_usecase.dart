/* Pushes dirty stock levels then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/stock_level_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushStockLevelsUseCase implements PushPort {
  final StockLevelSyncPort port;
  final SyncApiClient api;

  PushStockLevelsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final rows = await port.findDirty(limit: batchSize);
      if (rows.isEmpty) break;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final deltas = rows.map((m) {
        return StockLevelDeltaDto(
          id: m['id'] as int?,
          type: 'UPDATE',
          stockOnHand: (m['stockOnHand'] as int?) ?? 0,
          stockAllocated: (m['stockAllocated'] as int?) ?? 0,
          productVariantId: m['productVariantId'] as String?,
          companyId: m['companyId'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postStockLevelDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(
          'StockLevel sync failed with status ${res.statusCode}',
        );
      }
      await port.markSynced(rows.map((e) => e['id'] as int), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
