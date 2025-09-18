// Repository to fetch marketplace pages from REST API.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../marketplace/domain/entities/marketplace_item.dart';

class MarketplaceRepository {
  final String baseUri;
  MarketplaceRepository(this.baseUri);

  Future<MarketplacePageResult> fetchPage({
    required int page,
    int size = 20,
  }) async {
    final uri = Uri.parse('$baseUri/api/public/marketplace').replace(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'sort': 'createdAtAudit,DESC',
      },
    );

    final res = await http.get(uri, headers: {'accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      return MarketplacePageResult.fromJson(jsonMap);
    }
    throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
  }
}
