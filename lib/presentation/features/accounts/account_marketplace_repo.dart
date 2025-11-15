// lib/presentation/features/accounts/account_marketplace_repo.dart
// Marketplace HTTP repository for Account: POST/PUT/DELETE + list pull + reconcile
// - save(Account): POST si pas de remoteId, sinon PUT
// - saveAndReconcile(Account): save(...) puis GET côté /queries pour aligner (remoteId, status, flags, etc.)
// - deleteRemoteThenLocal(Account): DELETE distant puis softDelete local
// - pullAndReconcileList(): télécharge la liste distante et réconcilie tous les comptes locaux correspondants.
//
// NOTE montants : l'entité locale stocke des cents (int). L’API montre des décimaux.
// On envoie des doubles (cents / 100). À la réconciliation, on NE touche pas aux montants
// pour éviter d’écraser des modifications locales.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/domain/accounts/repositories/account_repository.dart';
import 'package:jaayko/presentation/features/accounts/account_repo_provider.dart';
import 'package:jaayko/sync/infrastructure/sync_headers_provider.dart';

final accountMarketplaceRepoProvider =
    Provider.family<AccountMarketplaceRepo, String>((ref, baseUri) {
      final httpClient = http.Client();
      final headerBuilder = ref.read(syncHeaderBuilderProvider);
      final localRepo = ref.read(accountRepoProvider);
      return AccountMarketplaceRepo(
        baseUri: baseUri,
        httpClient: httpClient,
        headerBuilder: headerBuilder,
        localRepo: localRepo,
      );
    });

class AccountMarketplaceRepo {
  final String baseUri;
  final http.Client httpClient;
  final Map<String, String> Function() headerBuilder;
  final AccountRepository localRepo;

  AccountMarketplaceRepo({
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

  // ---- Helpers montants : cents <-> double ----
  double? _toServerMoney(int? cents) => cents == null ? null : (cents / 100.0);

  // ---- Merge côté local depuis JSON distant (sans toucher aux montants) ----
  Account _mergeLocalFromRemoteJson(Account base, Map<String, dynamic> j) {
    final remoteId = (j['remoteId'] ?? j['id'] ?? base.remoteId ?? '')
        .toString();
    final status = (j['status'] ?? base.status)?.toString();
    final isDef = j['isDefault'] is bool
        ? j['isDefault'] as bool
        : base.isDefault;

    return base.copyWith(
      remoteId: remoteId.isNotEmpty ? remoteId : base.remoteId,
      status: status,
      isDefault: isDef,
      syncAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }

  Future<Account> _persistLocal(Account base) async {
    // Utilise updateFromSync si dispo pour éviter d’impacter version/etc.
    try {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      await (localRepo as dynamic).updateFromSync(base);
    } catch (_) {
      await localRepo.update(base);
    }
    return base;
  }

  // ===========================
  //            SAVE
  // ===========================

  Future<Account> _createRemote(Account a) async {
    final body = {
      'remoteId': a.remoteId,
      'localId': a.localId ?? a.id,
      'code': a.code,
      // Certaines APIs demandent 'name' : on met description ou code
      'name': (a.description?.isNotEmpty ?? false) ? a.description : a.code,
      'status': a.status,
      'currency': a.currency,
      'typeAccount': a.typeAccount,
      'balance': _toServerMoney(a.balance),
      'balancePrev': _toServerMoney(a.balancePrev),
      'balanceBlocked': _toServerMoney(a.balanceBlocked),
      'balanceInit': _toServerMoney(a.balanceInit),
      'balanceGoal': _toServerMoney(a.balanceGoal),
      'balanceLimit': _toServerMoney(a.balanceLimit),
      'description': a.description,
      'isDefault': a.isDefault,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.post(
      _u('/api/v1/commands/account'),
      headers: {...headerBuilder(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Create account failed: ${res.statusCode} ${res.body}');
    }

    final json = _decodeMap(res.body) ?? const {};
    final merged = _mergeLocalFromRemoteJson(a, json);
    return _persistLocal(merged);
  }

  Future<Account> _updateRemoteByRemoteIdOrCode(Account a) async {
    final idOrCode = (a.remoteId?.trim().isNotEmpty == true)
        ? a.remoteId!.trim()
        : (a.code ?? '').trim();

    if (idOrCode.isEmpty) {
      return _createRemote(a);
    }

    final body = {
      'remoteId': a.remoteId,
      'localId': a.localId ?? a.id,
      'code': a.code,
      'name': (a.description?.isNotEmpty ?? false) ? a.description : a.code,
      'status': a.status,
      'currency': a.currency,
      'typeAccount': a.typeAccount,
      'balance': _toServerMoney(a.balance),
      'balancePrev': _toServerMoney(a.balancePrev),
      'balanceBlocked': _toServerMoney(a.balanceBlocked),
      'balanceInit': _toServerMoney(a.balanceInit),
      'balanceGoal': _toServerMoney(a.balanceGoal),
      'balanceLimit': _toServerMoney(a.balanceLimit),
      'description': a.description,
      'isDefault': a.isDefault,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await httpClient.put(
      _u('/api/v1/commands/account/$idOrCode'),
      headers: {...headerBuilder(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Update account failed: ${res.statusCode} ${res.body}');
    }

    final json = _decodeMap(res.body) ?? const {};
    final merged = _mergeLocalFromRemoteJson(a, json);
    return _persistLocal(merged);
  }

  Future<Account> save(Account a) async {
    final hasRemoteId = (a.remoteId ?? '').trim().isNotEmpty;
    if (hasRemoteId) {
      return _updateRemoteByRemoteIdOrCode(a);
    } else {
      return _createRemote(a);
    }
  }

  Future<Account> saveAndReconcile(Account a) async {
    final saved = await save(a);
    final reconciled = await reconcileFromRemote(saved);
    return reconciled;
  }

  // ===========================
  //   RECONCILE ONE / BY CODE
  // ===========================

  Future<Map<String, dynamic>?> _fetchRemoteByRemoteIdOrCode(Account a) async {
    final headers = headerBuilder();

    final code = (a.code ?? '').trim();
    if (code.isNotEmpty) {
      final withCode = Uri.parse(
        '$baseUri/api/v1/queries/accounts?page=0&limit=10&code=${Uri.encodeQueryComponent(code)}',
      );
      final resCode = await httpClient.get(withCode, headers: headers);
      if (resCode.statusCode == 200) {
        final map = _decodeMap(resCode.body);
        final list =
            (map?['items'] ?? map?['content'] ?? []) as List? ?? const [];
        final found = list.cast<Map>().cast<Map<String, dynamic>?>().firstWhere(
          (e) => (e?['code']?.toString() ?? '') == code,
          orElse: () => null,
        );
        if (found != null) return found;
      }
    }

    // fallback: full list
    final listUri = Uri.parse(
      '$baseUri/api/v1/queries/accounts?page=0&limit=500',
    );
    final res = await httpClient.get(listUri, headers: headers);
    if (res.statusCode != 200) return null;

    final map = _decodeMap(res.body);
    final rows = (map?['items'] ?? map?['content'] ?? []) as List? ?? const [];
    final rid = (a.remoteId ?? '').trim();

    for (final r in rows) {
      final m = (r as Map).cast<String, dynamic>();
      final codeR = m['code']?.toString();
      final idR = m['id']?.toString();
      if ((code.isNotEmpty && codeR == code) ||
          (rid.isNotEmpty && idR == rid)) {
        return m;
      }
    }
    return null;
  }

  Future<Account> reconcileFromRemote(Account a) async {
    final j = await _fetchRemoteByRemoteIdOrCode(a);
    if (j == null) {
      final fallback = a.copyWith(updatedAt: DateTime.now(), isDirty: true);
      return _persistLocal(fallback);
    }
    final merged = _mergeLocalFromRemoteJson(a, j);
    return _persistLocal(merged);
  }

  // ===========================
  //           DELETE
  // ===========================

  Future<void> deleteRemote(Account a) async {
    final idOrCode = (a.remoteId?.trim().isNotEmpty == true)
        ? a.remoteId!.trim()
        : (a.code ?? '').trim();
    if (idOrCode.isEmpty) {
      throw Exception('Delete account requires a valid remoteId or code');
    }
    final res = await httpClient.delete(
      _u('/api/v1/commands/account/$idOrCode'),
      headers: headerBuilder(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete account failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Supprime côté serveur puis softDelete côté local.
  Future<void> deleteRemoteThenLocal(Account a) async {
    await localRepo.softDelete(a.id);
    await deleteRemote(a);
  }

  // ===========================
  //   PULL LIST & RECONCILE
  // ===========================

  /// Récupère la liste distante et réconcilie les comptes locaux correspondants.
  /// Retourne le nombre d’items locaux mis à jour.
  Future<int> pullAndReconcileList({int page = 0, int limit = 500}) async {
    final uri = Uri.parse(
      '$baseUri/api/v1/queries/accounts?page=$page&limit=$limit',
    );
    final res = await httpClient.get(uri, headers: headerBuilder());
    if (res.statusCode != 200) {
      throw Exception('Fetch accounts failed: ${res.statusCode} ${res.body}');
    }

    final map = _decodeMap(res.body) ?? const {};
    final rows = (map['items'] ?? map['content'] ?? []) as List? ?? const [];
    if (rows.isEmpty) return 0;

    // On construit un index {code|remoteId -> remoteJson}
    final Map<String, Map<String, dynamic>> byCode = {};
    final Map<String, Map<String, dynamic>> byId = {};
    for (final r in rows) {
      final m = (r as Map).cast<String, dynamic>();
      final code = (m['code'] ?? '').toString();
      final rid = (m['id'] ?? '').toString();
      if (code.isNotEmpty) byCode[code] = m;
      if (rid.isNotEmpty) byId[rid] = m;
    }

    // Charge tous les comptes locaux actifs
    final locals = await localRepo.findAllActive();
    int updated = 0;

    for (final a in locals) {
      final code = (a.code ?? '').trim();
      final rid = (a.remoteId ?? '').trim();

      Map<String, dynamic>? remote;
      if (rid.isNotEmpty && byId.containsKey(rid)) {
        remote = byId[rid];
      } else if (code.isNotEmpty && byCode.containsKey(code)) {
        remote = byCode[code];
      }

      if (remote == null) continue;

      final merged = _mergeLocalFromRemoteJson(a, remote);
      // Persiste uniquement si des changements réels (simple optimisation)
      final needUpdate =
          merged.remoteId != a.remoteId ||
          merged.status != a.status ||
          merged.isDefault != a.isDefault ||
          (merged.isDirty != a.isDirty) ||
          ((merged.syncAt ?? DateTime(0)) != (a.syncAt ?? DateTime(0)));

      if (needUpdate) {
        await _persistLocal(merged);
        updated++;
      }
    }

    return updated;
  }
}
