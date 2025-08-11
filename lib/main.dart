import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/app.dart';
import 'package:money_pulse/presentation/app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'fr_FR';
  await Future.wait([
    initializeDateFormatting('fr'),
    initializeDateFormatting('fr_FR'),
  ]);
  await AppDatabase.I.init();
  runApp(const ProviderScope(child: Bootstrap()));
}

class Bootstrap extends ConsumerStatefulWidget {
  const Bootstrap({super.key});

  @override
  ConsumerState<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<Bootstrap> {
  late final Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _init();
  }

  Future<void> _init() async {
    await ref.read(ensureDefaultAccountUseCaseProvider).execute();
    await ref.read(seedDefaultCategoriesUseCaseProvider).execute();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: Text('Erreur: ${snap.error}'))),
          );
        }
        return const AppRoot();
      },
    );
  }
}
