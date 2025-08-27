// Riverpod provider wiring AccountRepository to AppDatabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

import '../../../infrastructure/repositories/account_repository_sqflite.dart';
import '../../../onboarding/presentation/providers/access_session_provider.dart';

final accountRepoProvider = Provider<AccountRepository>((ref) {
  final appDb = ref.read(dbProvider);

  String? getUserId() => ref.read(accessSessionProvider)?.email;
  return AccountRepositorySqflite(appDb, getUserId: getUserId);
});
