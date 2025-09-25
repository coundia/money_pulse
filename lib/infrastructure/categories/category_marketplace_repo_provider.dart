// Marketplace HTTP repository for Category using header builder: create (POST), update (PUT), local unpublish.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import '../../sync/infrastructure/sync_headers_provider.dart';

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

  Future<Category> createRemote(Category c) async {
    final body = {
      'code': c.code,
      'name': c.code,
      'remoteId': c.remoteId,
      'localId': c.id,
      'account': c.account,
      'status': c.status,
      'isPublic': true,
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
    final json = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
    final remoteId = (json['remoteId'] ?? json['id'] ?? '').toString();
    final updated = c.copyWith(
      remoteId: remoteId.isNotEmpty ? remoteId : (c.remoteId ?? remoteId),
      syncAt: DateTime.now().toUtc(),
      isDirty: false,
      updatedAt: DateTime.now(),
    );
    await localRepo.update(updated);
    return updated;
  }

  Future<Category> updateRemote(Category c) async {
    final remodeId = c.remoteId;
    final body = {
      'id': remodeId,
      'code': c.code,
      'name': c.code,
      'remoteId': c.remoteId,
      'localId': c.id,
      'account': c.account,
      'status': c.status,
      'isPublic': true,
      'description': c.description,
      'typeEntry': c.typeEntry,
      'version': c.version,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.put(
      _u('/api/v1/commands/category/$remodeId'),
      headers: headerBuilder(),
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update category failed: ${res.statusCode} ${res.body}');
    }
    final updated = c.copyWith(
      syncAt: DateTime.now().toUtc(),
      isDirty: false,
      updatedAt: DateTime.now(),
    );
    await localRepo.update(updated);
    return updated;
  }

  Future<Category> publish(Category c) async {
    if ((c.remoteId ?? '').trim().isEmpty) {
      return createRemote(c);
    }
    return updateRemote(c);
  }

  Future<Category> unpublishLocal(Category c) async {
    final updated = c.copyWith(
      remoteId: null,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
    await localRepo.update(updated);
    return updated;
  }
}
