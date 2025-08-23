/* Minimal HTTP client for pushing deltas to remote sync endpoints. */
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, Object?>;

class SyncApiClient {
  final String baseUri;
  final http.Client _http;

  SyncApiClient(this.baseUri, this._http);

  Future<http.Response> postCategoryDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/category/sync'),
    {'deltas': deltas},
  );

  Future<http.Response> postAccountDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/balance/sync'),
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
    Uri.parse('$baseUri/api/v1/commands/transaction-item/sync'),
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
    Uri.parse('$baseUri/api/v1/commands/stock-level/sync'),
    {'deltas': deltas},
  );

  Future<http.Response> postStockMovementDeltas(List<Json> deltas) => _post(
    Uri.parse('$baseUri/api/v1/commands/stock-movement/sync'),
    {'deltas': deltas},
  );

  Future<http.Response> _post(Uri uri, Json body) {
    return _http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'accept': '*/*'},
      body: jsonEncode(body),
    );
  }
}

final httpClientProvider = Provider<http.Client>((_) => http.Client());

final syncApiClientProvider = Provider.family<SyncApiClient, String>((
  ref,
  baseUri,
) {
  final client = ref.read(httpClientProvider);
  return SyncApiClient(baseUri, client);
});
