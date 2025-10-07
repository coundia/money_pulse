// Marketplace item entity + page result (DDD friendly).
class MarketplaceItem {
  final String id;
  final String code;
  final String name;
  final String? description;

  final int defaultPrice;

  final int quantity;

  final bool hasSold;

  final bool hasPrice;

  final List<String> imageUrls;

  MarketplaceItem({
    required this.id,
    required this.code,
    required this.name,
    required this.defaultPrice,
    required this.imageUrls,
    required this.quantity,
    required this.hasSold,
    required this.hasPrice,
    this.description,
  });

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      defaultPrice: (json['defaultPrice'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      hasSold: (json['hasSold'] as bool?) ?? false,
      hasPrice: (json['hasPrice'] as bool?) ?? false,
      imageUrls: ((json['imageUrls'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class MarketplacePageResult {
  final List<MarketplaceItem> items;
  final bool hasNext;
  final int page;
  final int size;

  MarketplacePageResult({
    required this.items,
    required this.hasNext,
    required this.page,
    required this.size,
  });

  factory MarketplacePageResult.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List? ?? [])
        .map((e) => MarketplaceItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return MarketplacePageResult(
      items: content,
      hasNext: json['hasNext'] as bool? ?? false,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
    );
  }
}
