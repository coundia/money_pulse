// Receipt models: printable data for receipts including company and customer info.
class ReceiptLine {
  final String label;
  final int quantity;
  final int unitPrice;
  final int total;

  const ReceiptLine({
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class ReceiptData {
  final String id;
  final String title;
  final String? storeName;
  final String? accountLabel;
  final String? categoryLabel;
  final String typeEntry;
  final String currency;
  final DateTime date;
  final List<ReceiptLine> lines;
  final int subtotal;
  final int total;
  final String? footerNote;

  final String? companyName;
  final String? companyCode;
  final String? companyPhone;
  final String? companyEmail;
  final String? companyTaxId;
  final String? companyAddress;

  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

  const ReceiptData({
    required this.id,
    required this.title,
    required this.typeEntry,
    required this.currency,
    required this.date,
    required this.lines,
    required this.subtotal,
    required this.total,
    this.storeName,
    this.accountLabel,
    this.categoryLabel,
    this.footerNote,
    this.companyName,
    this.companyCode,
    this.companyPhone,
    this.companyEmail,
    this.companyTaxId,
    this.companyAddress,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
  });
}
