// Web implementation using window.close with graceful fallback.
import 'package:flutter/widgets.dart';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'app_exit_result.dart';

Future<AppExitResult> platformCloseApp(BuildContext context) async {
  try {
    html.window.close();
    html.window.open('', '_self');
    html.window.close();
    return AppExitResult.success(
      'Fermez l’onglet si la fermeture automatique échoue.',
    );
  } catch (_) {
    return AppExitResult.unsupported(
      'Veuillez fermer cet onglet manuellement.',
    );
  }
}
