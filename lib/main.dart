import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.I.init();
  runApp(const ProviderScope(child: Bootstrap()));
}

class Bootstrap extends ConsumerWidget {
  const Bootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: () async {
        await ref.read(ensureDefaultAccountUseCaseProvider).execute();
        await ref.read(seedDefaultCategoriesUseCaseProvider).execute();
      }(),
      builder: (_, __) => const AppRoot(),
    );
  }
}
