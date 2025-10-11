// App bootstrap with ProviderScope overrides.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite/sqflite.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/app.dart'; // <- AppRoot est ici
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';

// RouteObserver global utilisé par AutoRefreshOnFocus (didPopNext, etc.)
import 'package:money_pulse/presentation/navigation/route_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.empty,
    );
  };

  await Future.wait([
    initializeDateFormatting('fr'),
    initializeDateFormatting('fr_FR'),
  ]);
  Intl.defaultLocale = 'fr_FR';

  await AppDatabase.I.init();

  runZonedGuarded(() {
    runApp(
      RestartApp(
        child: ProviderScope(
          overrides: const [
            // Exemple si besoin :
            // syncPolicyProvider.overrideWithValue(
            //   const DisabledSetSyncPolicy({SyncDomain.stockMovements}),
            // ),
          ],
          child: const Bootstrap(),
        ),
      ),
    );
  }, (error, stack) {});
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
    _future = _init();
  }

  Future<void> _init() async {
    try {
      await ref.read(ensureDefaultAccountUseCaseProvider).execute();
    } on DatabaseException catch (e) {
      final msg = e.toString();
      if (!msg.contains('UNIQUE constraint failed')) {
        rethrow;
      }
    } catch (_) {}
  }

  Future<void> _retry() async {
    setState(() => _future = _init());
  }

  Future<void> _resetDbAndRetry() async {
    await AppDatabase.I.recreate(version: 1);
    if (!mounted) return;
    RestartApp.restart(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (_, snap) {
        // --- Écran de chargement ---
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
            navigatorObservers: [routeObserver], // ⬅️ important
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // --- Écran d’erreur ---
        if (snap.hasError) {
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
            navigatorObservers: [routeObserver], // ⬅️ important
            home: _BootstrapErrorScreen(
              error: snap.error!,
              onRetry: _retry,
              onResetDb: _resetDbAndRetry,
            ),
          );
        }

        // --- App normale ---
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
          navigatorObservers: [routeObserver], // ⬅️ indispensable
          home: const AppRoot(), // <- pas de MaterialApp imbriqué
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
