// Repository to fetch marketplace pages from REST API with search & filters.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../marketplace/domain/entities/marketplace_item.dart';

class MarketplaceRepository {
  final String baseUri;
  MarketplaceRepository(this.baseUri);

  /// Build query params and OMIT any null/empty values entirely.
  Map<String, String> _clean(Map<String, dynamic> src) {
    final out = <String, String>{};
    src.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      out[k] = v.toString();
    });
    return out;
  }

  Future<MarketplacePageResult> fetchPage({
    required int page,
    int size = 20,
    String? q,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? statusesCsv,
    String? companyId, // pass NULL for "All" — it will be omitted
  }) async {
    // NOTE: only include 'company' when companyId is non-null & non-empty.
    final qp = _clean({
      'page': page,
      'size': size,
      'sort': 'updatedAtAudit,DESC',
      if (q != null) 'q': q.trim(),
      if (category != null) 'category': category.trim(),
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (statusesCsv != null) 'statuses': statusesCsv.trim(),
      if (companyId != null && companyId.trim().isNotEmpty)
        'company': companyId.trim(),
    });

    final uri = Uri.parse(
      '$baseUri/api/public/marketplace',
    ).replace(queryParameters: qp);

    final res = await http.get(
      uri,
      headers: const {'accept': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final jsonMap = json.decode(res.body) as Map<String, dynamic>;
      return MarketplacePageResult.fromJson(jsonMap);
    }

    throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}: ${res.body}');
  }
}
