class ReportTotals {
  final int debitCents;
  final int creditCents;
  const ReportTotals({required this.debitCents, required this.creditCents});

  int get netCents => creditCents - debitCents;
}
