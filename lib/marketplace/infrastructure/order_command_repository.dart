// Repository to post order command to backend REST API v1 and log request payload.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/entities/order_command_request.dart';

class OrderCommandRepository {
  final String baseUri;
  const OrderCommandRepository({this.baseUri = 'http://127.0.0.1:8095'});

  Uri get _endpoint => Uri.parse('$baseUri/api/public/add/order');

  Future<void> send(OrderCommandRequest req) async {
    final bodyMap = req.toJson();
    final body = jsonEncode(bodyMap);

    debugPrint('[OrderCommandRepository] POST $_endpoint');
    debugPrint('[OrderCommandRepository] payload.map=$bodyMap');
    debugPrint('[OrderCommandRepository] payload.json=$body');

    final res = await http.post(
      _endpoint,
      headers: const {'accept': '*/*', 'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('[OrderCommandRepository] status=${res.statusCode}');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('[OrderCommandRepository] errorBody=${res.body}');
      throw Exception(
        'HTTP ${res.statusCode} ${res.reasonPhrase}: ${res.body}',
      );
    }
  }
}
