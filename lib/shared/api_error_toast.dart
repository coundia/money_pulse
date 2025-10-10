// lib/presentation/shared/api_error_toast.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Optionnel : remplacez par votre classe si vous en avez déjà une.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Tente d'extraire le PREMIER objet JSON équilibré `{...}` depuis une chaîne.
/// Parcourt tout le texte et essaie à chaque '{' de trouver l'accolade fermante correspondante.
/// Retourne `null` si rien de valide n'est trouvé.
Map<String, dynamic>? _extractFirstJsonMapBalanced(String s) {
  for (int start = 0; start < s.length; start++) {
    if (s[start] != '{') continue;
    int depth = 0;
    for (int end = start; end < s.length; end++) {
      final ch = s[end];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          final candidate = s.substring(start, end + 1);
          try {
            final decoded = jsonDecode(candidate);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {
            // continue scanning for next '{'
          }
          break; // on a fermé l'objet démarré à `start`, passer au prochain '{'
        }
      }
    }
  }
  return null;
}

/// Extrait un message lisible depuis n'importe quelle erreur.
/// - Gère ApiException
/// - Gère HttpException (y compris "... • {json}")
/// - Gère les Strings contenant du bruit + JSON (ex: "Exception: ... 500 {...}")
/// - Gère toute autre erreur via toString() + extraction éventuelle de JSON
String extractHumanError(Object error, {String fallback = 'Erreur serveur.'}) {
  // 1) ApiException
  if (error is ApiException) {
    return error.message.isNotEmpty ? error.message : fallback;
  }

  // 2) HttpException : peut contenir un JSON après " • " ou en fin de message
  if (error is HttpException) {
    final raw = error.message.trim();
    final map = _extractFirstJsonMapBalanced(raw);
    if (map != null) {
      final s = (map['message'] ?? map['error'] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return raw.isNotEmpty ? raw : fallback;
  }

  // 3) String : peut contenir "Exception: ... 500 { ... }"
  if (error is String) {
    final raw = error.trim();
    final map = _extractFirstJsonMapBalanced(raw);
    if (map != null) {
      final s = (map['message'] ?? map['error'] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return raw.isNotEmpty ? raw : fallback;
  }

  // 4) Dernier recours : toString + extraction éventuelle d’un JSON
  final raw = error.toString().trim();
  final map = _extractFirstJsonMapBalanced(raw);
  if (map != null) {
    final s = (map['message'] ?? map['error'] ?? '').toString().trim();
    if (s.isNotEmpty) return s;
  }
  return raw.isNotEmpty ? raw : fallback;
}

/// Affiche un SnackBar avec un message d'erreur propre.
void showApiErrorSnackBar(
  BuildContext context,
  Object error, {
  String fallback = 'Erreur serveur.',
  Duration duration = const Duration(seconds: 4),
}) {
  final message = extractHumanError(error, fallback: fallback);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), duration: duration));
}
