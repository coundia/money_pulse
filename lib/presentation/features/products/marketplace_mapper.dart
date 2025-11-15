import 'package:jaayko/domain/products/entities/product.dart';

Map<String, dynamic> productToMarketplaceJson(
  Product p, {
  String? account,
  String? unit,
  String? localId,
}) {
  // L’API attend des prix en décimal (pas en cents).
  double centsToDec(int c) => (c / 100.0);

  return {
    'remoteId': p.remoteId,
    'localId': localId,
    'code': p.code,
    'name': p.name,
    'description': p.description,
    'barcode': p.barcode,
    'unit': unit,
    'syncAt': p.syncAt?.toIso8601String(),
    'category': p.categoryId,
    'account': account,
    'defaultPrice': centsToDec(p.defaultPrice),
    'statuses': p.statuses,
    'purchasePrice': centsToDec(p.purchasePrice),
  };
}
