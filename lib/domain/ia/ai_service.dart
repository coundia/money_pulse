// Contract for AI service

import 'ai_classification_result.dart';

abstract class AiService {
  Future<AiClassificationResult> classify(String text);
}
