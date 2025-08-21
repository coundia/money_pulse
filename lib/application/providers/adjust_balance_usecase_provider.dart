// Riverpod provider that exposes AdjustBalanceUseCase wired with db and repository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/application/usecases/adjust_balance_usecase.dart';

final adjustBalanceUseCaseProvider = Provider<AdjustBalanceUseCase>((ref) {
  final db = ref.read(dbProvider) as AppDatabase;
  final repo = ref.read(accountRepoProvider);
  return AdjustBalanceUseCase(db: db, accountRepo: repo);
});
