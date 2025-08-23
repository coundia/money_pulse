/* Pushes dirty units then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/unit_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushUnitsUseCase implements PushPort {
  final UnitSyncPort port;
  final SyncApiClient api;

  PushUnitsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final rows = await port.findDirty(limit: batchSize);
      if (rows.isEmpty) break;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final deltas = rows.map((m) {
        final deletedAt = m['deletedAt'];
        final type = deletedAt == null ? 'UPDATE' : 'DELETE';
        return UnitDeltaDto(
          id: m['id'] as String,
          type: type,
          code: (m['code'] ?? '') as String,
          name: m['name'] as String?,
          remoteId: m['remoteId'] as String?,
          description: m['description'] as String?,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postUnitDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Unit sync failed with status ${res.statusCode}');
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
