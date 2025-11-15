/* Marketplace HTTP repository for Company:
 * POST/PUT/DELETE + publish/unpublish/republish with strict local reconciliation.
 */
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/presentation/app/providers/company_repo_provider.dart';
import 'package:jaayko/domain/company/repositories/company_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_headers_provider.dart';

final companyMarketplaceRepoProvider =
    Provider.family<CompanyMarketplaceRepo, String>((ref, baseUri) {
      final httpClient = http.Client();
      final headerBuilder = ref.read(syncHeaderBuilderProvider);
      final localRepo = ref.read(companyRepoProvider);
      return CompanyMarketplaceRepo(
        baseUri: baseUri,
        httpClient: httpClient,
        headerBuilder: headerBuilder,
        localRepo: localRepo,
      );
    });

class CompanyMarketplaceRepo {
  final String baseUri;
  final http.Client httpClient;
  final Map<String, String> Function() headerBuilder;
  final CompanyRepository localRepo;

  CompanyMarketplaceRepo({
    required this.baseUri,
    required this.httpClient,
    required this.headerBuilder,
    required this.localRepo,
  });

  Uri _u(String p) => Uri.parse('$baseUri$p');

  Map<String, dynamic>? _decodeMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Company _mergeLocalFromRemoteJson(Company base, Map<String, dynamic> j) {
    final remoteId = (j['remoteId'] ?? j['id'] ?? base.remoteId ?? '')
        .toString();
    final status = (j['status'] ?? base.status)?.toString();
    final isPublic = j['isPublic'] is bool
        ? j['isPublic'] as bool
        : base.isPublic;
    final isActive = j['isActive'] is bool
        ? j['isActive'] as bool
        : base.isActive;

    return base.copyWith(
      remoteId: remoteId.isNotEmpty ? remoteId : base.remoteId,
      status: status,
      isPublic: isPublic,
      isActive: isActive,
      syncAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }

  Future<Company> _persistLocal(Company base) async {
    // Méthode spécialisée du repo local pour les MAJ "provenant du serveur".
    await localRepo.updateFromSync(base);
    return base;
  }

  // ------------------------
  // CREATE / UPDATE
  // ------------------------

  Future<Company> createRemote(Company c) async {
    final body = {
      'remoteId': c.remoteId,
      'localId': c.localId ?? c.id,
      'code': c.code,
      'name': c.name,
      'description': c.description,
      'phone': c.phone,
      'email': c.email,
      'website': c.website,
      'taxId': c.taxId,
      'currency': c.currency,
      'addressLine1': c.addressLine1,
      'addressLine2': c.addressLine2,
      'city': c.city,
      'region': c.region,
      'country': c.country,
      'account': c.account,
      'postalCode': c.postalCode,
      'isActive': c.isActive,
      'status': c.status ?? 'PUBLISH',
      'isPublic': c.isPublic,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'isDefault': c.isDefault,
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.post(
      _u('/api/v1/commands/company'),
      headers: headerBuilder(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create company failed: ${res.statusCode} ${res.body}');
    }

    final json = _decodeMap(res.body) ?? const {};
    final merged = _mergeLocalFromRemoteJson(c, json);
    return _persistLocal(merged);
  }

  Future<Company> updateRemoteByRemoteId(Company c) async {
    final id = (c.remoteId ?? '').trim();
    final pathId = id.isNotEmpty ? id : c.code; // fallback si remoteId manquant

    final body = {
      'remoteId': c.remoteId,
      'localId': c.localId ?? c.id,
      'code': c.code,
      'name': c.name,
      'description': c.description,
      'phone': c.phone,
      'email': c.email,
      'website': c.website,
      'taxId': c.taxId,
      'currency': c.currency,
      'addressLine1': c.addressLine1,
      'addressLine2': c.addressLine2,
      'city': c.city,
      'region': c.region,
      'country': c.country,
      'account': c.account,
      'postalCode': c.postalCode,
      'isActive': c.isActive,
      'status': c.status ?? 'PUBLISH',
      'isPublic': c.isPublic,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'isDefault': c.isDefault,
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.put(
      _u('/api/v1/commands/company/$pathId'),
      headers: headerBuilder(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update company failed: ${res.statusCode} ${res.body}');
    }

    final json = _decodeMap(res.body) ?? const {};
    final merged = _mergeLocalFromRemoteJson(c, json);
    return _persistLocal(merged);
  }

  Future<Company> save(Company c) async {
    final hasRemoteId = (c.remoteId ?? '').trim().isNotEmpty;
    if (hasRemoteId) {
      return updateRemoteByRemoteId(c);
    } else {
      return createRemote(c);
    }
  }

  // ------------------------
  // PUBLISH / UNPUBLISH
  // ------------------------

  Future<Company> publish(Company c) async {
    final want = c.copyWith(status: 'PUBLISH', isPublic: true, isActive: true);
    final updated = await save(want);
    return reconcileFromRemote(updated);
  }

  Future<Company> unpublish(Company c) async {
    final want = c.copyWith(
      status: 'UNPUBLISH',
      isPublic: false,
      isActive: false,
    );
    final updated = await save(want);
    return reconcileFromRemote(updated);
  }

  Future<Company> republish(Company c) async {
    return publish(c);
  }

  // ------------------------
  // DELETE (API) + stratégies locales
  // ------------------------

  /// Appelle l’API DELETE `/commands/company/{id|code}`.
  /// Retourne simplement si OK, sinon lance une Exception.
  Future<void> _deleteRemoteCall(Company c) async {
    final idOrCode = (c.remoteId?.trim().isNotEmpty == true)
        ? c.remoteId!.trim()
        : c.code.trim();
    if (idOrCode.isEmpty) {
      throw Exception('Delete company requires a valid remoteId or code');
    }
    final res = await httpClient.delete(
      _u('/api/v1/commands/company/$idOrCode'),
      headers: headerBuilder(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete company failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Supprime côté API **mais conserve la ligne locale**.
  /// - Nettoie `remoteId`
  /// - Force le statut local à UNPUBLISH / isPublic=false / isActive=false
  /// - Marque `isDirty=true` pour un éventuel re-publish ultérieur
  Future<Company> deleteRemoteAndKeepLocal(Company c) async {
    await _deleteRemoteCall(c);

    final now = DateTime.now().toUtc();
    final local = c.copyWith(
      remoteId: null,
      status: 'UNPUBLISH',
      isPublic: false,
      isActive: false,
      updatedAt: now,
      syncAt: now,
      isDirty: true,
    );

    await localRepo.updateFromSync(local);
    return local;
  }

  /// Supprime côté API **et** soft delete la ligne locale.
  Future<void> deleteRemoteAndSoftDeleteLocal(Company c) async {
    await _deleteRemoteCall(c);
    await localRepo.softDelete(c.id);
  }

  // ------------------------
  // RECONCILIATION (GET /queries)
  // ------------------------

  Future<Map<String, dynamic>?> _fetchRemoteByRemoteIdOrCode(Company c) async {
    final headers = headerBuilder();

    // Essai avec filtre code (si backend le supporte)
    final withCode = Uri.parse(
      '$baseUri/api/v1/queries/companies?page=0&limit=10&code=${Uri.encodeQueryComponent(c.code)}',
    );
    final resCode = await httpClient.get(withCode, headers: headers);
    if (resCode.statusCode == 200) {
      final map = _decodeMap(resCode.body);
      final list =
          (map?['items'] ?? map?['content'] ?? []) as List? ?? const [];
      final found = list.cast<Map>().cast<Map<String, dynamic>?>().firstWhere(
        (e) => (e?['code']?.toString() ?? '') == c.code,
        orElse: () => null,
      );
      if (found != null) return found;
    }

    // Fallback : liste large, filtrage côté client
    final listUri = Uri.parse(
      '$baseUri/api/v1/queries/companies?page=0&limit=500',
    );
    final res = await httpClient.get(listUri, headers: headers);
    if (res.statusCode != 200) return null;
    final map = _decodeMap(res.body);
    final rows = (map?['items'] ?? map?['content'] ?? []) as List? ?? const [];
    for (final r in rows) {
      final m = (r as Map).cast<String, dynamic>();
      final code = m['code']?.toString();
      final rid = m['id']?.toString();
      if (code == c.code ||
          (c.remoteId?.isNotEmpty == true && rid == c.remoteId)) {
        return m;
      }
    }
    return null;
  }

  Future<Company> reconcileFromRemote(Company c) async {
    final j = await _fetchRemoteByRemoteIdOrCode(c);
    if (j == null) {
      // Non trouvé côté serveur → garder l’info locale mais forcer isDirty
      final fallback = c.copyWith(updatedAt: DateTime.now(), isDirty: true);
      return _persistLocal(fallback);
    }
    final merged = _mergeLocalFromRemoteJson(c, j);
    return _persistLocal(merged);
  }
}
