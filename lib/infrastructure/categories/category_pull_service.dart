// Pulls categories from remote paginated endpoint and merges locally by code.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/presentation/app/providers.dart';

import '../../sync/infrastructure/sync_headers_provider.dart';

final categoryPullServiceProvider =
    Provider.family<CategoryPullService, String>((ref, baseUri) {
      final httpClient = http.Client();
      final headerBuilder = ref.read(syncHeaderBuilderProvider);
      final localRepo = ref.read(categoryRepoProvider);
      return CategoryPullService(
        httpClient: httpClient,
        headerBuilder: headerBuilder,
        baseUri: baseUri,
        localRepo: localRepo,
      );
    });

class CategoryPullService {
  final http.Client httpClient;
  final Map<String, String> Function() headerBuilder;
  final String baseUri;
  final CategoryRepository localRepo;

  CategoryPullService({
    required this.httpClient,
    required this.headerBuilder,
    required this.baseUri,
    required this.localRepo,
  });

  Uri _u(int page, int limit) =>
      Uri.parse('$baseUri/api/v1/queries/categories?page=$page&limit=$limit');

  Future<int> syncAll({int pageSize = 200, int maxPages = 100}) async {
    final now = DateTime.now();
    final existing = await localRepo.findAllActive();
    final byCode = <String, Category>{
      for (final c in existing) c.code.toLowerCase(): c,
    };

    var totalUpserts = 0;
    for (var page = 0; page < maxPages; page++) {
      final res = await httpClient.get(
        _u(page, pageSize),
        headers: headerBuilder(),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'Pull categories failed: ${res.statusCode} ${res.body}',
        );
      }
      final parsed = jsonDecode(res.body);
      final list = _extractList(parsed);
      if (list.isEmpty) break;

      for (final raw in list) {
        final remote = _mapRemote(raw);
        final key = remote.code.toLowerCase();
        final existing = byCode[key];
        if (existing == null) {
          final toCreate = Category(
            id: const Uuid().v4(),
            localId: null,
            remoteId: remote.remoteId,
            code: remote.code,
            description: remote.description,
            createdAt: remote.createdAt ?? now,
            updatedAt: remote.updatedAt ?? now,
            deletedAt: remote.deletedAt,
            syncAt: now,
            account: remote.account,
            version: remote.version ?? 0,
            isDirty: false,
            typeEntry: remote.typeEntry ?? Category.debit,
            status: remote.status,
            isPublic: remote.isPublic ?? true,
          );
          await localRepo.create(toCreate);
          byCode[key] = toCreate;
          totalUpserts++;
        } else {
          final updated = existing.copyWith(
            remoteId: remote.remoteId ?? existing.remoteId,
            description: remote.description ?? existing.description,
            account: remote.account ?? existing.account,
            typeEntry: (remote.typeEntry ?? existing.typeEntry).toUpperCase(),
            status: remote.status ?? existing.status,
            isPublic: remote.isPublic ?? existing.isPublic,
            version: remote.version ?? existing.version,
            updatedAt: remote.updatedAt ?? now,
            syncAt: now,
            isDirty: false,
          );
          await localRepo.update(updated);
          byCode[key] = updated;
          totalUpserts++;
        }
      }

      if (list.length < pageSize) break;
    }

    return totalUpserts;
  }

  List<dynamic> _extractList(dynamic parsed) {
    if (parsed is List) return parsed;
    if (parsed is Map<String, dynamic>) {
      for (final k in const ['data', 'items', 'content', 'results', 'rows']) {
        final v = parsed[k];
        if (v is List) return v;
      }
    }
    return const [];
  }

  _RemoteCat _mapRemote(Map<String, dynamic> m) {
    String? _s(String k) => (m[k] ?? m[k.camel] ?? m[k.snake])?.toString();
    bool? _b(String k) {
      final v = m[k] ?? m[k.camel] ?? m[k.snake];
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
    }

    DateTime? _d(String k) {
      final v = m[k] ?? m[k.camel] ?? m[k.snake];
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    int? _i(String k) {
      final v = m[k] ?? m[k.camel] ?? m[k.snake];
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final code = _s('code') ?? '';
    final typeEntry = (_s('typeEntry') ?? '').toUpperCase();
    return _RemoteCat(
      code: code,
      remoteId: _s('remoteId') ?? _s('id'),
      description: _s('description'),
      account: _s('account'),
      status: _s('status'),
      isPublic: _b('isPublic'),
      typeEntry: (typeEntry == Category.credit)
          ? Category.credit
          : Category.debit,
      version: _i('version'),
      createdAt: _d('createdAt'),
      updatedAt: _d('updatedAt'),
      deletedAt: _d('deletedAt'),
    );
  }
}

class _RemoteCat {
  final String code;
  final String? remoteId;
  final String? description;
  final String? account;
  final String? status;
  final bool? isPublic;
  final String? typeEntry;
  final int? version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  _RemoteCat({
    required this.code,
    this.remoteId,
    this.description,
    this.account,
    this.status,
    this.isPublic,
    this.typeEntry,
    this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });
}

extension on String {
  String get snake =>
      replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
  String get camel {
    final parts = split('_');
    if (parts.length == 1) return this;
    return parts.first +
        parts
            .skip(1)
            .map(
              (p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}',
            )
            .join();
  }
}
