// File: lib/shared/server_unavailable.dart
// Utilitaire réutilisable pour afficher un message court à l'utilisateur
// ("Serveur momentanément indisponible") et LOGUER les détails techniques.
// À utiliser partout où un appel réseau peut échouer.

import 'dart:developer' as dev;
import 'package:flutter/material.dart';

class ServerUnavailable {
  /// Affiche un SnackBar court et log les détails techniques (erreur + stack).
  ///
  /// [where] permet d’indiquer un contexte (ex: "TransactionListPage.pull").
  /// [actionLabel] + [onAction] pour ajouter un CTA type "Réessayer".
  static void showSnackBar(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String? where,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    // 1) Log technique (console/devtools)
    final tag = where == null || where.isEmpty ? 'server_unavailable' : where;
    dev.log(
      'Server unavailable: $error',
      name: tag,
      stackTrace: stackTrace,
      error: error,
    );

    // 2) Message court et clair pour l’utilisateur
    final snack = SnackBar(
      duration: duration,
      content: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Serveur momentanément indisponible')),
        ],
      ),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snack);
  }
}
