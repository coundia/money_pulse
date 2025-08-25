/* HTTP client for sync: ensures GET /queries/{entity}/syncAt uses RFC3339 UTC with milliseconds (e.g. 2025-08-24T08:49:04.201Z). */
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:money_pulse/sync/infrastructure/sync_headers_provider.dart';

typedef Json = Map<String, Object?>;

class SyncApiClient {
  final String baseUri;
  final http.Client _http;
  final HeaderBuilder _headers;

  SyncApiClient(this.baseUri, this._http, this._headers);

  Future<http.Response> postCategoryDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/category/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postAccountDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/account/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postTransactionDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/transaction/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postUnitDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/unit/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postProductDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/product/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postTransactionItemDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/transactionItem/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postCompanyDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/company/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postCustomerDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/customer/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postDebtDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/debt/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postStockLevelDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/stockLevel/sync'),
    {'deltas': deltas},
  );
  Future<http.Response> postStockMovementDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/stockMovement/sync'),
    {'deltas': deltas},
  );

  Future<List<Json>> getBySyncAt(String entity, DateTime since) async {
    final iso = _formatMillisZ(since);

    final uri = Uri.parse(
      '$baseUri/api/v1/queries/$entity/syncAt',
    ).replace(queryParameters: {'syncAt': iso});
    final resp = await _get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final body = jsonDecode(resp.body);
      if (body is List) {
        return body.cast<Map>().map((e) => e.cast<String, Object?>()).toList();
      }
      return const [];
    }
    throw StateError('GET $entity/syncAt failed: ${resp.statusCode}');
  }

  Future<List<Json>> getAccountsSince(DateTime since) =>
      getBySyncAt('account', since);
  Future<List<Json>> getCategoriesSince(DateTime since) =>
      getBySyncAt('category', since);
  Future<List<Json>> getUnitsSince(DateTime since) =>
      getBySyncAt('unit', since);
  Future<List<Json>> getProductsSince(DateTime since) =>
      getBySyncAt('product', since);
  Future<List<Json>> getCompaniesSince(DateTime since) =>
      getBySyncAt('company', since);
  Future<List<Json>> getCustomersSince(DateTime since) =>
      getBySyncAt('customer', since);
  Future<List<Json>> getDebtsSince(DateTime since) =>
      getBySyncAt('debt', since);
  Future<List<Json>> getTransactionsSince(DateTime since) =>
      getBySyncAt('transaction', since);
  Future<List<Json>> getTransactionItemsSince(DateTime since) =>
      getBySyncAt('transactionItem', since);
  Future<List<Json>> getStockLevelsSince(DateTime since) =>
      getBySyncAt('stockLevel', since);
  Future<List<Json>> getStockMovementsSince(DateTime since) =>
      getBySyncAt('stockMovement', since);

  Future<http.Response> _post(Uri uri, Json body) {
    return _http.post(uri, headers: _headers(), body: jsonEncode(body));
  }

  Future<http.Response> _get(Uri uri) {
    return _http.get(uri, headers: _headers());
  }

  String _formatMillisZ(DateTime dt) {
    final u = dt.isUtc ? dt : dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final mo = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    final h = u.hour.toString().padLeft(2, '0');
    final mi = u.minute.toString().padLeft(2, '0');
    final s = u.second.toString().padLeft(2, '0');
    final ms = u.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-$d'
        'T'
        '$h:$mi:$s.$ms'
        'Z';
  }
}

final httpClientProvider = Provider<http.Client>((_) => http.Client());

final syncApiClientProvider = Provider.family<SyncApiClient, String>((
  ref,
  baseUri,
) {
  final client = ref.read(httpClientProvider);
  final headers = ref.read(syncHeaderBuilderProvider);
  return SyncApiClient(baseUri, client, headers);
});
