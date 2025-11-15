// Marketplace HTTP repository for Category using header builder.
// Create/Update/Unpublish/Publish and now Delete (remote) + helper to delete both remote and local.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:jaayko/domain/categories/entities/category.dart';
import 'package:jaayko/domain/categories/repositories/category_repository.dart';
import 'package:jaayko/presentation/app/providers.dart';

import '../../sync/infrastructure/sync_headers_provider.dart';
// Adapte l'import si ton chemin diffère

final categoryMarketplaceRepoProvider =
    Provider.family<CategoryMarketplaceRepo, String>((ref, baseUri) {
      final httpClient = http.Client();
      final headerBuilder = ref.read(syncHeaderBuilderProvider);
      final localRepo = ref.read(categoryRepoProvider);
      return CategoryMarketplaceRepo(
        ref: ref,
        baseUri: baseUri,
        httpClient: httpClient,
        headerBuilder: headerBuilder,
        localRepo: localRepo,
      );
    });

class CategoryMarketplaceRepo {
  final Ref ref;
  final String baseUri;
  final http.Client httpClient;
  final Map<String, String> Function() headerBuilder;
  final CategoryRepository localRepo;

  CategoryMarketplaceRepo({
    required this.ref,
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

  Future<Category> _persistLocal(
    Category base, {
    String? remoteId,
    String? status,
    bool? isPublic,
    DateTime? syncAt,
    bool? isDirty,
    DateTime? deletedAt,
  }) async {
    final updated = base.copyWith(
      remoteId: remoteId ?? base.remoteId,
      status: status ?? base.status,
      isPublic: isPublic ?? base.isPublic,
      syncAt: syncAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now(),
      isDirty: isDirty ?? base.isDirty,
      deletedAt: deletedAt ?? base.deletedAt,
    );
    await localRepo.update(updated);
    return updated;
  }

  Future<Category> createRemote(
    Category c, {
    String? forceStatus,
    bool? forceIsPublic,
  }) async {
    final desiredStatus = (forceStatus ?? c.status ?? 'PUBLISH').toUpperCase();
    final desiredIsPublic = forceIsPublic ?? c.isPublic;

    final body = {
      'code': c.code,
      'name': c.code,
      'remoteId': c.remoteId,
      'localId': c.localId ?? c.id,
      'account': c.account,
      'status': desiredStatus,
      'isPublic': desiredIsPublic,
      'description': c.description,
      'typeEntry': c.typeEntry,
      'version': c.version,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.post(
      _u('/api/v1/commands/category'),
      headers: headerBuilder(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create category failed: ${res.statusCode} ${res.body}');
    }

    final json = await _decode(res.body) ?? const {};
    final remoteId = (json['remoteId'] ?? json['id'] ?? c.remoteId ?? '')
        .toString();
    final status = (json['status'] ?? desiredStatus).toString();
    final isPublic = json['isPublic'] is bool
        ? json['isPublic'] as bool
        : desiredIsPublic;

    return _persistLocal(
      c,
      remoteId: remoteId.isNotEmpty ? remoteId : c.remoteId,
      status: status,
      isPublic: isPublic,
      isDirty: false,
    );
  }

  Future<Category> updateRemoteByCode(
    Category c, {
    String? forceStatus,
    bool? forceIsPublic,
  }) async {
    final desiredStatus = (forceStatus ?? c.status ?? 'PUBLISH').toUpperCase();
    final desiredIsPublic = forceIsPublic ?? c.isPublic;

    final codePath = c.remoteId;

    final body = {
      'code': c.code,
      'name': c.code,
      'remoteId': c.remoteId,
      'localId': c.localId ?? c.id,
      'account': c.account,
      'status': desiredStatus,
      'isPublic': desiredIsPublic,
      'description': c.description,
      'typeEntry': c.typeEntry,
      'version': c.version,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.put(
      _u('/api/v1/commands/category/$codePath'),
      headers: headerBuilder(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update category failed: ${res.statusCode} ${res.body}');
    }

    final json = await _decode(res.body) ?? const {};
    final remoteId = (json['remoteId'] ?? json['id'] ?? c.remoteId ?? '')
        .toString();
    final status = (json['status'] ?? desiredStatus).toString();
    final isPublic = json['isPublic'] is bool
        ? json['isPublic'] as bool
        : desiredIsPublic;

    return _persistLocal(
      c,
      remoteId: remoteId.isNotEmpty ? remoteId : c.remoteId,
      status: status,
      isPublic: isPublic,
      isDirty: false,
    );
  }

  Future<Category> publish(Category c) async {
    final want = c.copyWith(status: 'PUBLISH', isPublic: true);
    if ((c.remoteId ?? '').trim().isEmpty) {
      return createRemote(want, forceStatus: 'PUBLISH', forceIsPublic: true);
    }
    return updateRemoteByCode(
      want,
      forceStatus: 'PUBLISH',
      forceIsPublic: true,
    );
  }

  Future<Category> unpublish(Category c) async {
    final want = c.copyWith(status: 'UNPUBLISH', isPublic: false);
    return updateRemoteByCode(
      want,
      forceStatus: 'UNPUBLISH',
      forceIsPublic: false,
    );
  }

  Future<void> deleteRemote(Category c) async {
    // Utilise remoteId si présent, sinon code (ton cURL montre un path avec l'id/code)
    final idOrCode = (c.remoteId?.trim().isNotEmpty == true)
        ? c.remoteId!.trim()
        : c.code.trim();
    if (idOrCode.isEmpty) {
      throw Exception('Delete requires a valid remoteId or code');
    }
    final res = await httpClient.delete(
      _u('/api/v1/commands/category/$idOrCode'),
      headers: headerBuilder(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete category failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteBoth(Category c) async {
    await localRepo.softDelete(c.id);
    await deleteRemote(c);
  }
}
