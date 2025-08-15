// Default (fallback) implementation for unsupported platforms.
import 'package:flutter/widgets.dart';
import 'app_exit_result.dart';

Future<AppExitResult> platformCloseApp(BuildContext context) async {
  return AppExitResult.unsupported(
    'Fermeture non supportée sur cette plateforme.',
  );
}
