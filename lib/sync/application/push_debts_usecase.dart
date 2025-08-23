/* Pushes dirty debts then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/debt_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushDebtsUseCase implements PushPort {
  final DebtSyncPort port;
  final SyncApiClient api;

  PushDebtsUseCase(this.port, this.api);

  @override
  Future<int> execute({int batchSize = 200}) async {
    int total = 0;
    while (true) {
      final rows = await port.findDirty(limit: batchSize);
      if (rows.isEmpty) break;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final deltas = rows.map((m) {
        final remoteId = m['remoteId'] as String?;
        final type = remoteId == null ? 'CREATE' : 'UPDATE';
        return DebtDeltaDto(
          id: m['id'] as String,
          type: type,
          remoteId: m['remoteId'] as String?,
          code: m['code'] as String?,
          notes: m['notes'] as String?,
          balance: (m['balance'] as int?) ?? 0,
          balanceDebt: (m['balanceDebt'] as int?) ?? 0,
          dueDate: m['dueDate'] as String?,
          statuses: m['statuses'] as String?,
          customerId: m['customerId'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          deletedAt: null,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postDebtDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Debt sync failed with status ${res.statusCode}');
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
