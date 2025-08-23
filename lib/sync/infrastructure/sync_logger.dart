/* Simple sync logger with info/warn/error and a Riverpod provider. */
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncLogger {
  void info(String message);
  void warn(String message);
  void error(String message, [Object? err, StackTrace? st]);
}

class DebugSyncLogger implements SyncLogger {
  @override
  void info(String message) {
    if (!kReleaseMode) dev.log(message, name: 'sync', level: 800);
  }

  @override
  void warn(String message) {
    dev.log(message, name: 'sync', level: 900);
  }

  @override
  void error(String message, [Object? err, StackTrace? st]) {
    dev.log(message, name: 'sync', level: 1000, error: err, stackTrace: st);
  }
}

final syncLoggerProvider = Provider<SyncLogger>((_) => DebugSyncLogger());
