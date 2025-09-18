// Entity representing structured result of AI classification

class AiClassificationResult {
  final int amount;
  final String category;
  final String type;
  final DateTime date;
  final String description;

  AiClassificationResult({
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.description,
  });
}
