/* Sync logger that mirrors to dev.log and console to ensure visibility in all modes. */
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SyncLogger {
  void info(String message);
  void warn(String message);
  void error(String message, [Object? err, StackTrace? st]);
}

class DebugSyncLogger implements SyncLogger {
  final bool verbose;
  final bool mirrorToPrint;

  DebugSyncLogger({this.verbose = true, this.mirrorToPrint = true});

  void _emit(String message, int level, [Object? err, StackTrace? st]) {
    dev.log(message, name: 'sync', level: level, error: err, stackTrace: st);
    if (mirrorToPrint) {
      final tag = level >= 1000
          ? 'ERROR'
          : level >= 900
          ? 'WARN'
          : 'INFO';
      debugPrint('[sync][$tag] $message${err != null ? ' $err' : ''}');
      if (st != null) debugPrint(st.toString());
    }
  }

  @override
  void info(String message) {
    if (verbose) _emit(message, 800);
  }

  @override
  void warn(String message) => _emit(message, 900);

  @override
  void error(String message, [Object? err, StackTrace? st]) =>
      _emit(message, 1000, err, st);
}

final syncLogVerboseProvider = Provider<bool>(
  (_) => const bool.fromEnvironment('SYNC_LOG_VERBOSE', defaultValue: true),
);

final syncLogMirrorToPrintProvider = Provider<bool>(
  (_) => const bool.fromEnvironment('SYNC_LOG_PRINT', defaultValue: true),
);

final syncLoggerProvider = Provider<SyncLogger>((ref) {
  final verbose = ref.watch(syncLogVerboseProvider);
  final mirror = ref.watch(syncLogMirrorToPrintProvider);
  return DebugSyncLogger(verbose: verbose, mirrorToPrint: mirror);
});
