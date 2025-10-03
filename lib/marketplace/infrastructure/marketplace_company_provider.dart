// Simple repository + providers to load public companies for marketplace filter.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class MarketplaceCompany {
  final String id;
  final String code;
  final String name;
  final bool isDefault;
  final bool isActive;
  const MarketplaceCompany({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.isActive,
  });
  factory MarketplaceCompany.fromJson(Map<String, dynamic> j) =>
      MarketplaceCompany(
        id: (j['id'] ?? j['remoteId'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        isDefault: (j['isDefault'] ?? false) == true,
        isActive: (j['isActive'] ?? false) == true,
      );
}

class MarketplaceCompanyRepository {
  final String baseUri;
  MarketplaceCompanyRepository(this.baseUri);

  Future<List<MarketplaceCompany>> fetch({
    int page = 0,
    int limit = 100,
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
    return content.map((e) => MarketplaceCompany.fromJson(e)).toList();
  }
}

final marketplaceCompanyRepoProvider =
    Provider.family<MarketplaceCompanyRepository, String>(
      (ref, baseUri) => MarketplaceCompanyRepository(baseUri),
    );

final marketplaceCompaniesProvider =
    FutureProvider.family<List<MarketplaceCompany>, String>((ref, baseUri) {
      final repo = ref.read(marketplaceCompanyRepoProvider(baseUri));
      return repo.fetch(page: 0, limit: 100);
    });
