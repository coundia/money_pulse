// Repository to fetch marketplace pages from REST API with search & filters.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../marketplace/domain/entities/marketplace_item.dart';

class MarketplaceRepository {
  final String baseUri;
  MarketplaceRepository(this.baseUri);

  Future<MarketplacePageResult> fetchPage({
    required int page,
    int size = 20,
    String? q,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? statusesCsv, // e.g. "PUBLISH,PROMO"
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'size': '$size',
      'sort': 'updatedAtAudit,DESC',
    };

    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (category != null && category.trim().isNotEmpty) {
      qp['category'] = category.trim();
    }
    if (minPrice != null) qp['minPrice'] = '$minPrice';
    if (maxPrice != null) qp['maxPrice'] = '$maxPrice';
    if (statusesCsv != null && statusesCsv.trim().isNotEmpty) {
      qp['statuses'] = statusesCsv.trim();
    }

    final uri = Uri.parse(
      '$baseUri/api/public/marketplace',
    ).replace(queryParameters: qp);

    final res = await http.get(uri, headers: {'accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      return MarketplacePageResult.fromJson(jsonMap);
    }
    throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
  }
}
