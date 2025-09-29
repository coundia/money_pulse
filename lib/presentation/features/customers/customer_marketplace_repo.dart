import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';

import '../../app/providers/customer_repo_provider.dart';

/// Simplified marketplace repo for syncing customers with a remote server.
/// Assumes baseUrl like: http://127.0.0.1:8095
class CustomerMarketplaceRepo {
  final Ref ref;
  final String baseUrl;
  CustomerMarketplaceRepo(this.ref, this.baseUrl);

  CustomerRepository get _repo => ref.read(customerRepoProvider);

  Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: qp);

  double _toRemoteAmount(int cents) => cents / 100.0;
  int _fromRemoteAmount(num v) => (v * 100).round();

  Map<String, dynamic> _toRemote(Customer c) {
    return {
      'remoteId': c.remoteId,
      'localId': c.id,
      'code': c.code,
      'firstName': c.firstName,
      'lastName': c.lastName,
      'fullName': c.fullName.isNotEmpty
          ? c.fullName
          : '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim(),
      'balance': _toRemoteAmount(c.balance),
      'balanceDebt': _toRemoteAmount(c.balanceDebt),
      'phone': c.phone,
      'email': c.email,
      'notes': c.notes,
      'status': c.status,
      'account': c.account,
      'company': c.companyId,
      'addressLine1': c.addressLine1,
      'addressLine2': c.addressLine2,
      'city': c.city,
      'region': c.region,
      'country': c.country,
      'postalCode': c.postalCode,
      'syncAt': DateTime.now().toUtc().toIso8601String(),
      'isActive': (c.deletedAt == null),
    };
  }

  Customer _fromRemote(Map<String, dynamic> m) {
    // The remote may return snakeCase/camelCase; be defensive
    int cents(num? v) => v == null ? 0 : _fromRemoteAmount(v);
    String? s(String k) => (m[k] ?? m[_alt(k)])?.toString();
    num? n(String k) {
      final v = m[k] ?? m[_alt(k)];
      if (v is num) return v;
      return num.tryParse('$v');
    }

    return Customer(
      id: s('localId') ?? s('id') ?? s('remoteId') ?? '',
      remoteId: s('remoteId'),
      code: s('code'),
      firstName: s('firstName'),
      lastName: s('lastName'),
      fullName: s('fullName') ?? '',
      balance: cents(n('balance')),
      balanceDebt: cents(n('balanceDebt')),
      phone: s('phone'),
      email: s('email'),
      notes: s('notes'),
      status: s('status'),
      account: s('account') ?? s('accountId'),
      companyId: s('company') ?? s('companyId') ?? '',
      addressLine1: s('addressLine1'),
      addressLine2: s('addressLine2'),
      city: s('city'),
      region: s('region'),
      country: s('country'),
      postalCode: s('postalCode'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: null,
      version: 0,
      isDirty: false,
    );
  }

  String _alt(String k) {
    // quick alt mapping (camel <-> snake)
    final map = <String, String>{
      'remoteId': 'remote_id',
      'localId': 'local_id',
      'firstName': 'first_name',
      'lastName': 'last_name',
      'fullName': 'full_name',
      'balanceDebt': 'balance_debt',
      'addressLine1': 'address_line1',
      'addressLine2': 'address_line2',
      'postalCode': 'postal_code',
      'accountId': 'account_id',
      'companyId': 'company_id',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
      'deletedAt': 'deleted_at',
    };
    return map[k] ?? k;
  }

  /// Pull remote customers and reconcile locally (very simple upsert by id or remoteId).
  Future<int> pullAndReconcileList({int page = 0, int limit = 200}) async {
    final res = await http.get(
      _u('/api/v1/queries/customers', {'page': '$page', 'limit': '$limit'}),
      headers: const {'accept': 'application/json'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET customers failed: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(res.body);
    List data;
    if (body is List) {
      data = body;
    } else if (body is Map && body['items'] is List) {
      data = List<Map<String, dynamic>>.from(body['items']);
    } else if (body is Map && body['data'] is List) {
      data = List<Map<String, dynamic>>.from(body['data']);
    } else {
      data = [];
    }

    int updated = 0;
    for (final it in data.cast<Map<String, dynamic>>()) {
      final remote = _fromRemote(it);
      // try by id, otherwise create
      final local = await _repo.findById(remote.id);
      if (local == null) {
        await _repo.create(remote);
        updated++;
      } else {
        await _repo.update(
          local.copyWith(
            remoteId: remote.remoteId ?? local.remoteId,
            code: remote.code ?? local.code,
            firstName: remote.firstName ?? local.firstName,
            lastName: remote.lastName ?? local.lastName,
            fullName: (remote.fullName.isNotEmpty
                ? remote.fullName
                : local.fullName),
            balance: remote.balance,
            balanceDebt: remote.balanceDebt,
            phone: remote.phone ?? local.phone,
            email: remote.email ?? local.email,
            notes: remote.notes ?? local.notes,
            status: remote.status ?? local.status,
            addressLine1: remote.addressLine1 ?? local.addressLine1,
            addressLine2: remote.addressLine2 ?? local.addressLine2,
            city: remote.city ?? local.city,
            region: remote.region ?? local.region,
            country: remote.country ?? local.country,
            postalCode: remote.postalCode ?? local.postalCode,
            updatedAt: DateTime.now(),
            isDirty: false,
          ),
        );
        updated++;
      }
    }
    return updated;
  }

  /// POST (no remoteId) or PUT (with remoteId), then reconcile local record.
  Future<void> saveAndReconcile(Customer c) async {
    final body = jsonEncode(_toRemote(c));
    http.Response res;
    if ((c.remoteId ?? '').isEmpty) {
      res = await http.post(
        _u('/api/v1/commands/customer'),
        headers: const {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    } else {
      res = await http.put(
        _u('/api/v1/commands/customer/${c.remoteId}'),
        headers: const {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Save failed: ${res.statusCode} ${res.body}');
    }

    // Try to capture remoteId from response if returned
    String? remoteId;
    try {
      final m = jsonDecode(res.body);
      if (m is Map && (m['remoteId'] ?? m['id']) != null) {
        remoteId = '${m['remoteId'] ?? m['id']}';
      }
    } catch (_) {}

    // Mark local as clean + set remoteId if obtained
    await _repo.update(
      c.copyWith(
        remoteId: remoteId ?? c.remoteId,
        isDirty: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// DELETE remote (if remoteId present), then soft-delete local.
  Future<void> deleteRemoteThenLocal(Customer c) async {
    final remoteId = (c.remoteId ?? '').trim();
    if (remoteId.isNotEmpty) {
      final res = await http.delete(
        _u('/api/v1/commands/customer/$remoteId'),
        headers: const {'accept': '*/*'},
      );
      // Accept 2xx and 404 as "ok" for idempotency
      if (!(res.statusCode >= 200 && res.statusCode < 300) &&
          res.statusCode != 404) {
        throw Exception('Remote delete failed: ${res.statusCode} ${res.body}');
      }
    }
    await _repo.softDelete(c.id);
  }
}

/// Riverpod provider.family to build a repo per baseUrl.
final customerMarketplaceRepoProvider =
    Provider.family<CustomerMarketplaceRepo, String>(
      (ref, baseUrl) => CustomerMarketplaceRepo(ref, baseUrl),
    );
