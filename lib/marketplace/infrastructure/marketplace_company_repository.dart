// Repository to fetch public companies for marketplace filter.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/entities/marketplace_company.dart';

class MarketplaceCompanyRepository {
  final String baseUri;
  MarketplaceCompanyRepository(this.baseUri);

  Future<List<MarketplaceCompany>> fetchCompanies({
    int page = 0,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '$baseUri/api/public/queries/companies',
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'});

    final res = await http.get(uri, headers: {'accept': 'application/json'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
    }
    final m = json.decode(res.body) as Map<String, dynamic>;
    final content = (m['content'] as List? ?? const []);
    return content
        .map((e) => MarketplaceCompany.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
