/* Pushes dirty customers then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/customer_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushCustomersUseCase implements PushPort {
  final CustomerSyncPort port;
  final SyncApiClient api;

  PushCustomersUseCase(this.port, this.api);

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
        return CustomerDeltaDto(
          id: m['id'] as String,
          type: type,
          remoteId: m['remoteId'] as String?,
          code: m['code'] as String?,
          firstName: m['firstName'] as String?,
          lastName: m['lastName'] as String?,
          fullName: m['fullName'] as String?,
          balance: (m['balance'] as int?) ?? 0,
          balanceDebt: (m['balanceDebt'] as int?) ?? 0,
          phone: m['phone'] as String?,
          email: m['email'] as String?,
          notes: m['notes'] as String?,
          status: m['status'] as String?,
          companyId: m['companyId'] as String?,
          addressLine1: m['addressLine1'] as String?,
          addressLine2: m['addressLine2'] as String?,
          city: m['city'] as String?,
          region: m['region'] as String?,
          country: m['country'] as String?,
          postalCode: m['postalCode'] as String?,
          createdAt: (m['createdAt'] as String?) ?? nowIso,
          updatedAt: (m['updatedAt'] as String?) ?? nowIso,
          deletedAt: deletedAt,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postCustomerDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Customer sync failed with status ${res.statusCode}');
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
