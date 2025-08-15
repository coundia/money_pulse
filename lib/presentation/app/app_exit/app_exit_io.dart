// IO implementation (Android, iOS, Windows, macOS, Linux).
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app_exit_result.dart';

Future<AppExitResult> platformCloseApp(BuildContext context) async {
  try {
    if (Platform.isIOS) {
      return AppExitResult.unsupported(
        'iOS ne permet pas de fermer l’app programmatique­ment.',
      );
    }
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
      return AppExitResult.success('Fermeture demandée.');
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      exit(0);
    }
    return AppExitResult.unsupported('Plateforme non reconnue.');
  } catch (e) {
    return AppExitResult.failed('Échec de la fermeture : $e');
  }
}
