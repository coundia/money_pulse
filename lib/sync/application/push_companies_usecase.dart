/* Pushes dirty companies then marks them synced. */
import 'package:money_pulse/sync/domain/dtos/company_delta_dto.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';

class PushCompaniesUseCase implements PushPort {
  final CompanySyncPort port;
  final SyncApiClient api;

  PushCompaniesUseCase(this.port, this.api);

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
        return CompanyDeltaDto(
          id: m['id'] as String,
          type: type,
          code: (m['code'] ?? '') as String,
          name: m['name'] as String?,
          remoteId: m['remoteId'] as String?,
          description: m['description'] as String?,
          phone: m['phone'] as String?,
          email: m['email'] as String?,
          website: m['website'] as String?,
          taxId: m['taxId'] as String?,
          currency: m['currency'] as String?,
          addressLine1: m['addressLine1'] as String?,
          addressLine2: m['addressLine2'] as String?,
          city: m['city'] as String?,
          region: m['region'] as String?,
          country: m['country'] as String?,
          postalCode: m['postalCode'] as String?,
          isDefault: ((m['isDefault'] as int?) ?? 0) == 1,
          version: (m['version'] as int?) ?? 0,
          syncAt: nowIso,
        ).toJson();
      }).toList();
      final res = await api.postCompanyDeltas(deltas);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Company sync failed with status ${res.statusCode}');
      }
      await port.markSynced(rows.map((e) => e['id'] as String), DateTime.now());
      total += rows.length;
      if (rows.length < batchSize) break;
    }
    return total;
  }
}
