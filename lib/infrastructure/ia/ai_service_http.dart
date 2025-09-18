// Implementation of AiService using Spring middleware API

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/ia/ai_classification_result.dart';
import '../../domain/ia/ai_service.dart';

class AiServiceHttp implements AiService {
  final String baseUrl;

  AiServiceHttp(this.baseUrl);

  @override
  Future<AiClassificationResult> classify(String text) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/v1/ai/classify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AiClassificationResult(
        amount: data["amount"],
        category: data["category"],
        type: data["type"],
        date: DateTime.parse(data["date"]),
        description: data["category"],
      );
    } else {
      throw Exception("AI Service error: ${response.statusCode}");
    }
  }
}
