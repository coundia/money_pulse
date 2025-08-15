// Cross-platform facade selecting the right platform implementation.
import 'package:flutter/widgets.dart';
import 'app_exit_result.dart';
import 'app_exit_stub.dart'
    if (dart.library.io) 'app_exit_io.dart'
    if (dart.library.html) 'app_exit_web.dart';

class AppExit {
  static Future<AppExitResult> requestClose(BuildContext context) {
    return platformCloseApp(context);
  }
}
