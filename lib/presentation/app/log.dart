// lib/presentation/app/log.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

typedef _Printer =
    void Function(String msg, {String tag, Object? error, StackTrace? st});

class Log {
  static bool _inited = false;
  static late _Printer d;
  static late _Printer e;

  /// Call this in main() *before* anything else.
  static void init({String defaultTag = 'App'}) {
    if (_inited) return;
    _inited = true;

    // send logs to both dev.log (Logcat) and print (Flutter console)
    d = (String msg, {String tag = 'App', Object? error, StackTrace? st}) {
      dev.log(msg, name: tag, error: error, stackTrace: st);
      // print keeps Flutter "Run" console happy, and survives some filters
      // keep single line for better readability
      // ignore: avoid_print
      print(
        '[$tag] $msg${error != null ? " | error=$error" : ""}${st != null ? "\n$st" : ""}',
      );
    };
    e = d;

    // Widen Flutter’s debugPrint to avoid truncation of long lines
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null) return;
      dev.log(message, name: defaultTag);
      // ignore: avoid_print
      print('[$defaultTag] $message');
    };
  }

  /// Global error wiring (optional but useful)
  static void wireGlobalErrorHooks({String tag = 'Startup'}) {
    FlutterError.onError = (details) {
      e(
        'FlutterError.onError',
        tag: tag,
        error: details.exception,
        st: details.stack,
      );
      // still forward to default behavior in debug
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.empty,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      e('PlatformDispatcher.onError', tag: tag, error: error, st: stack);
      return true;
    };
  }
}
