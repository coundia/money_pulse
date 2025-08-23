/* Pushes dirty products then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/product_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushProductsUseCase implements PushPort {
  final ProductSyncPort port;
  final SyncApiClient api;

  PushProductsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final rows = await port.findDirty(limit: batchSize);
      if (rows.isEmpty) break;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final deltas = rows.map((m) {
        final deletedAt = m['deletedAt'] as String?;
        final type = deletedAt == null ? 'UPDATE' : 'DELETE';
        return ProductDeltaDto(
          id: m['id'] as String,
          type: type,
          remoteId: m['remoteId'] as String?,
          code: m['code'] as String?,
          name: m['name'] as String?,
          description: m['description'] as String?,
          barcode: m['barcode'] as String?,
          unitId: m['unitId'] as String?,
          categoryId: m['categoryId'] as String?,
          defaultPrice: (m['defaultPrice'] as int?) ?? 0,
          purchasePrice: (m['purchasePrice'] as int?) ?? 0,
          statuses: m['statuses'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          deletedAt: deletedAt,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postProductDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Product sync failed with status ${res.statusCode}');
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
