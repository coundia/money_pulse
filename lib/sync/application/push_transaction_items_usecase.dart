/* Pushes dirty transaction items then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/transaction_item_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushTransactionItemsUseCase implements PushPort {
  final TransactionItemSyncPort port;
  final SyncApiClient api;

  PushTransactionItemsUseCase(this.port, this.api);

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
        return TransactionItemDeltaDto(
          id: m['id'] as String,
          type: type,
          transactionId: m['transactionId'] as String,
          productId: m['productId'] as String?,
          label: m['label'] as String?,
          quantity: (m['quantity'] as int?) ?? 0,
          unitId: m['unitId'] as String?,
          unitPrice: (m['unitPrice'] as int?) ?? 0,
          total: (m['total'] as int?) ?? 0,
          notes: m['notes'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          deletedAt: deletedAt,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postTransactionItemDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError(
          'TransactionItem sync failed with status ${res.statusCode}',
        );
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
