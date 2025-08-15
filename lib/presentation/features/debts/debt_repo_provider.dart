// Riverpod provider wiring DebtRepository to AppDatabase.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';
import 'package:money_pulse/infrastructure/debts/repositories/debt_repository_sqflite.dart';

final debtRepoProvider = Provider<DebtRepository>((ref) {
  final db = ref.read(dbProvider);
  return DebtRepositorySqflite(db);
});
