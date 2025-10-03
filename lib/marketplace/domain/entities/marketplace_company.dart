// Readmodel for a company returned by /api/public/queries/companies.
class MarketplaceCompany {
  final String id;
  final String code;
  final String name;
  final bool isDefault;

  const MarketplaceCompany({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
  });

  factory MarketplaceCompany.fromJson(Map<String, dynamic> j) {
    return MarketplaceCompany(
      id: (j['id'] ?? j['remoteId'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      isDefault: (j['isDefault'] ?? false) == true,
    );
  }
}
