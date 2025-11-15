// HTTP implementation for ChatRepository with overridable header builder and network logs.
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:jaayko/domain/chat/entities/chat_models.dart';
import 'package:jaayko/domain/chat/repositories/chat_repository.dart';

typedef HeaderBuilder = Map<String, String> Function();

class ChatRepositoryHttp implements ChatRepository {
  final String baseUri;
  final http.Client _client;
  final HeaderBuilder? headerBuilder;

  ChatRepositoryHttp(this.baseUri, {http.Client? client, this.headerBuilder})
    : _client = client ?? http.Client();

  Map<String, String> _baseHeaders({String? bearerToken}) {
    final h = <String, String>{
      'accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (headerBuilder != null) {
      h.addAll(headerBuilder!.call());
    } else if (bearerToken != null && bearerToken.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearerToken';
    }
    return h;
  }

  String _mask(String v) {
    if (v.length <= 10) return '***';
    return '${v.substring(0, 6)}...${v.substring(v.length - 4)}';
  }

  void _logRequestResponse({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? bodyOut,
    int? status,
    String? bodyIn,
    Object? error,
  }) {
    final safeHeaders = Map<String, String>.from(headers);
    final auth = safeHeaders['Authorization'];
    if (auth != null && auth.isNotEmpty) {
      final parts = auth.split(' ');
      safeHeaders['Authorization'] = parts.length == 2
          ? '${parts[0]} ${_mask(parts[1])}'
          : _mask(auth);
    }
    final payload = <String, dynamic>{
      'method': method,
      'url': uri.toString(),
      'headers': safeHeaders,
      if (bodyOut != null) 'bodyOut': bodyOut,
      if (status != null) 'status': status,
      if (bodyIn != null) 'bodyIn': bodyIn,
      if (error != null) 'error': error.toString(),
    };
    final line = jsonEncode(payload);
    dev.log(line, name: 'chat_api');
    if (kDebugMode) {
      // debugPrint('[chat_api] $line');
    }
  }

  @override
  Future<void> sendMessage({
    required String text,
    required String accountId,
    String? bearerToken,
  }) async {
    final now = DateTime.now().toUtc();
    final uuid = const Uuid();

    final bodyMap = {
      "messages": text,
      "state": "INIT",
      "localId": uuid.v4(),
      "account": accountId,
      "dateTransaction": now.toIso8601String(),
    };

    final uri = Uri.parse('$baseUri/api/v1/commands/chat');
    final headers = _baseHeaders(bearerToken: bearerToken);
    final body = jsonEncode(bodyMap);

    _logRequestResponse(
      method: 'POST',
      uri: uri,
      headers: headers,
      bodyOut: body,
    );

    http.Response resp;
    try {
      resp = await _client.post(uri, headers: headers, body: body);
    } catch (e) {
      _logRequestResponse(
        method: 'POST',
        uri: uri,
        headers: headers,
        bodyOut: body,
        error: e,
      );
      rethrow;
    }

    _logRequestResponse(
      method: 'POST',
      uri: uri,
      headers: headers,
      status: resp.statusCode,
      bodyIn: resp.body,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        'Erreur envoi message (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  @override
  Future<ChatPageResult> fetchMessages({
    required int page,
    required int limit,
    String? bearerToken,
  }) async {
    final uri = Uri.parse(
      '$baseUri/api/v1/queries/chats?page=$page&limit=$limit',
    );
    final headers = _baseHeaders(bearerToken: bearerToken);

    _logRequestResponse(method: 'GET', uri: uri, headers: headers);

    http.Response resp;
    try {
      resp = await _client.get(uri, headers: headers);
    } catch (e) {
      _logRequestResponse(method: 'GET', uri: uri, headers: headers, error: e);
      rethrow;
    }

    _logRequestResponse(
      method: 'GET',
      uri: uri,
      headers: headers,
      status: resp.statusCode,
      bodyIn: resp.body,
    );

    if (resp.statusCode != 200) {
      throw Exception(
        'Erreur chargement messages (${resp.statusCode}): ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body);

    // Supporte soit "content":[], soit "items":[]
    final raw = (data['content'] ?? data['items'] ?? []) as List<dynamic>;

    final items = raw.map((m) {
      final remoteId = (m['remoteId'] ?? '').toString();
      final localId = (m['localId'] ?? '').toString();
      final idAny = (m['id'] ?? remoteId ?? localId ?? '').toString();

      final txt = (m['messages'] ?? m['text'] ?? m['message'] ?? '').toString();

      final createdAtStr =
          (m['dateTransaction'] ??
                  m['syncAt'] ??
                  m['createdAt'] ??
                  DateTime.now().toIso8601String())
              .toString();
      final createdAt =
          DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();

      final stateStr = (m['state'] ?? '').toString().toUpperCase();
      final hasRemote = remoteId.isNotEmpty;

      ChatDeliveryStatus? status;
      if (stateStr == 'COMPLETED') {
        status = ChatDeliveryStatus.processed; // ✓✓ vert
      } else if (stateStr == 'FAIL') {
        status = ChatDeliveryStatus.failed; // ✓✓ rouge
      } else if (hasRemote) {
        status = ChatDeliveryStatus.delivered; // ✓✓ gris
      } else {
        status = null; // inconnu (pas de coches)
      }

      // On considère "messages" (payload utilisateur) => isMe
      final isMe = (m['messages'] ?? '') != '';

      return ChatMessageEntity(
        id: idAny.isEmpty ? const Uuid().v4() : idAny,
        remoteId: remoteId.isEmpty ? null : remoteId,
        localId: localId.isEmpty ? null : localId,
        sender: isMe ? 'Moi' : 'IA',
        text: txt,
        createdAt: createdAt,
        isMe: isMe,
        status: status,
      );
    }).toList();

    // tri du plus récent au plus ancien (affichage courant)
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final total =
        (data['totalElements'] ?? data['total'] ?? items.length) as int? ??
        items.length;
    final pageFromApi =
        (data['page'] ?? data['number'] ?? page) as int? ?? page;
    final sizeFromApi =
        (data['size'] ?? data['limit'] ?? limit) as int? ?? limit;
    final hasMore = ((pageFromApi + 1) * sizeFromApi) < total;

    return ChatPageResult(
      items: items,
      page: pageFromApi,
      limit: sizeFromApi,
      hasMore: hasMore,
    );
  }

  @override
  Future<void> deleteByRemoteId(String remoteId, {String? bearerToken}) async {
    final uri = Uri.parse('$baseUri/api/v1/commands/chat/$remoteId');
    final headers = _baseHeaders(bearerToken: bearerToken);

    _logRequestResponse(method: 'DELETE', uri: uri, headers: headers);

    http.Response resp;
    try {
      resp = await _client.delete(uri, headers: headers);
    } catch (e) {
      _logRequestResponse(
        method: 'DELETE',
        uri: uri,
        headers: headers,
        error: e,
      );
      rethrow;
    }

    _logRequestResponse(
      method: 'DELETE',
      uri: uri,
      headers: headers,
      status: resp.statusCode,
      bodyIn: resp.body,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Erreur suppression (${resp.statusCode}): ${resp.body}');
    }
  }
}
