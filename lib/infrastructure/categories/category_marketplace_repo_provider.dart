// Marketplace HTTP repository for Category using header builder.
// Creates (POST) or updates (PUT by code) on remote, and always updates local copy in sync.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import '../../sync/infrastructure/sync_headers_provider.dart';

// NOTE: change this import if your path differs

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

  Future<Map<String, dynamic>?> _decode(String body) {
    if (body.trim().isEmpty) return Future.value(null);
    try {
      final v = jsonDecode(body);
      return Future.value(v is Map<String, dynamic> ? v : null);
    } catch (_) {
      return Future.value(null);
    }
  }

  Future<Category> _persistLocal(
    Category base, {
    String? remoteId,
    String? status,
    bool? isPublic,
    DateTime? syncAt,
    bool isDirty = false,
  }) async {
    final updated = base.copyWith(
      remoteId: remoteId ?? base.remoteId,
      status: status ?? base.status,
      isPublic: isPublic ?? base.isPublic,
      syncAt: syncAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now(),
      isDirty: isDirty,
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

    // Per your cURL, backend expects PUT with the code in path
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
    // Remote: set status UNPUBLISH and isPublic false; Local: reflect the same.
    final want = c.copyWith(status: 'UNPUBLISH', isPublic: false);
    // Si remoteId absent, on met quand même à jour par code (backend attend le code en path).
    return updateRemoteByCode(
      want,
      forceStatus: 'UNPUBLISH',
      forceIsPublic: false,
    );
  }
}
