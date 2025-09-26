// Marketplace HTTP repository for Company using header builder: POST, PUT, DELETE, publish/unpublish with local sync.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/app/providers/company_repo_provider.dart';

import '../../../domain/company/repositories/company_repository.dart';
import '../../../sync/infrastructure/sync_headers_provider.dart';
// Adapt the import path if needed

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

  Future<Map<String, dynamic>?> _decode(String body) async {
    if (body.trim().isEmpty) return null;
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<Company> _persistLocal(
    Company base, {
    String? remoteId,
    String? status,
    bool? isPublic,
    bool? isActive,
    DateTime? syncAt,
    bool? isDirty,
  }) async {
    final updated = base.copyWith(
      remoteId: remoteId ?? base.remoteId,
      status: status ?? base.status,
      isPublic: isPublic ?? base.isPublic,
      isActive: isActive ?? base.isActive,
      syncAt: syncAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now(),
      isDirty: isDirty ?? false,
    );
    await localRepo.update(updated);
    return updated;
  }

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

    final json = await _decode(res.body) ?? const {};
    final remoteId = (json['remoteId'] ?? json['id'] ?? c.remoteId ?? '')
        .toString();
    final status = (json['status'] ?? c.status ?? 'PUBLISH').toString();
    final isPublic = json['isPublic'] is bool
        ? json['isPublic'] as bool
        : c.isPublic;
    final isActive = json['isActive'] is bool
        ? json['isActive'] as bool
        : c.isActive;

    return _persistLocal(
      c,
      remoteId: remoteId.isNotEmpty ? remoteId : c.remoteId,
      status: status,
      isPublic: isPublic,
      isActive: isActive,
      isDirty: false,
    );
  }

  Future<Company> updateRemoteByRemoteId(Company c) async {
    final id = (c.remoteId ?? '').trim();
    final pathId = id.isNotEmpty ? id : c.code; // fallback if remoteId missing

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

    final json = await _decode(res.body) ?? const {};
    final remoteId = (json['remoteId'] ?? json['id'] ?? c.remoteId ?? '')
        .toString();
    final status = (json['status'] ?? c.status ?? 'PUBLISH').toString();
    final isPublic = json['isPublic'] is bool
        ? json['isPublic'] as bool
        : c.isPublic;
    final isActive = json['isActive'] is bool
        ? json['isActive'] as bool
        : c.isActive;

    return _persistLocal(
      c,
      remoteId: remoteId.isNotEmpty ? remoteId : c.remoteId,
      status: status,
      isPublic: isPublic,
      isActive: isActive,
      isDirty: false,
    );
  }

  Future<Company> publish(Company c) async {
    final want = c.copyWith(status: 'PUBLISH', isPublic: true);
    if ((c.remoteId ?? '').trim().isEmpty) {
      return createRemote(want);
    }
    return updateRemoteByRemoteId(want);
  }

  Future<Company> unpublish(Company c) async {
    final want = c.copyWith(status: 'UNPUBLISH', isPublic: false);
    return updateRemoteByRemoteId(want);
  }

  Future<void> deleteRemote(Company c) async {
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
}
