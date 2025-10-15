// lib/main.dart (or wherever your main() lives)
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/app/log.dart'; // <-- add
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/app.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';
import 'package:money_pulse/presentation/navigation/route_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init logging FIRST so early logs are visible in both consoles
  Log.init(defaultTag: 'Startup');
  Log.wireGlobalErrorHooks(tag: 'Startup');

  // catch errors from other isolates
  Isolate.current.addErrorListener(
    RawReceivePort((pair) {
      final List<dynamic> errorAndStacktrace = pair;
      Log.e(
        'IsolateError',
        tag: 'Startup',
        error: errorAndStacktrace.first,
        st: errorAndStacktrace.last,
      );
    }).sendPort,
  );

  Log.d('Initializing locale & DB', tag: 'Startup');

  await Future.wait([
    initializeDateFormatting('fr'),
    initializeDateFormatting('fr_FR'),
  ]);
  Intl.defaultLocale = 'fr_FR';

  await AppDatabase.I.init();
  Log.d('DB init done', tag: 'Startup');

  runZonedGuarded(
    () {
      Log.d('runApp()', tag: 'Startup');
      runApp(
        RestartApp(
          child: ProviderScope(overrides: const [], child: const Bootstrap()),
        ),
      );
    },
    (error, stack) {
      Log.e('Uncaught in Zone', tag: 'Startup', error: error, st: stack);
    },
  );
}

class Bootstrap extends ConsumerStatefulWidget {
  const Bootstrap({super.key});
  @override
  ConsumerState<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<Bootstrap> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    Log.d('Bootstrap.initState');
    _future = _init();
  }

  Future<void> _init() async {
    try {
      Log.d('Bootstrap._init start');
      await ref.read(ensureDefaultAccountUseCaseProvider).execute();
      Log.d('Bootstrap._init done');
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (!msg.contains('UNIQUE constraint failed')) rethrow;
      Log.d('Bootstrap._init UNIQUE constraint ignored');
    } catch (e, st) {
      Log.e('Bootstrap._init error', error: e, st: st);
    }
  }

  Future<void> _retry() async {
    Log.d('Bootstrap._retry');
    setState(() => _future = _init());
  }

  Future<void> _resetDbAndRetry() async {
    Log.d('Bootstrap._resetDbAndRetry');
    await AppDatabase.I.recreate(version: 1);
    if (!mounted) return;
    RestartApp.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    Log.d('Bootstrap.build');
    return FutureBuilder<void>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Money Pulse',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF2563EB),
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr'), Locale('fr', 'FR')],
            navigatorObservers: [routeObserver],
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snap.hasError) {
          Log.e('Bootstrap Future error screen', error: snap.error);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Money Pulse',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF2563EB),
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr'), Locale('fr', 'FR')],
            navigatorObservers: [routeObserver],
            home: _BootstrapErrorScreen(
              error: snap.error!,
              onRetry: _retry,
              onResetDb: _resetDbAndRetry,
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Money Pulse',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF2563EB),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr'), Locale('fr', 'FR')],
          navigatorObservers: [routeObserver],
          home: const AppRoot(),
        );
      },
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final Future<void> Function() onResetDb;
  const _BootstrapErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onResetDb,
  });

  @override
  Widget build(BuildContext context) {
    Log.e('BootstrapErrorScreen.build', error: error);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'Impossible de démarrer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onResetDb,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Réinitialiser la base'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
