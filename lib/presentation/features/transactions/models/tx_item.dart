class TxItem {
  final String productId;
  final String label;
  final int unitPriceCents;
  final int quantity;

  const TxItem({
    required this.productId,
    required this.label,
    required this.unitPriceCents,
    required this.quantity,
  });
}
