/* Pushes dirty accounts then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/account_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushAccountsUseCase implements PushPort {
  final AccountSyncPort port;
  final SyncApiClient api;

  PushAccountsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final items = await port.findDirty(limit: batchSize);
      if (items.isEmpty) break;
      final now = DateTime.now();
      final deltas = items
          .map(
            (a) => AccountDeltaDto.fromEntity(
              a,
              a.remoteId == null ? SyncDeltaType.create : SyncDeltaType.update,
              now,
            ).toJson(),
          )
          .toList();
      final res = await api.postAccountDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Account sync failed with status ${res.statusCode}');
      }
      await port.markSynced(items.map((e) => e.id), now);
      total += items.length;
      if (items.length < batchSize) break;
    }
    return total;
  }
}
