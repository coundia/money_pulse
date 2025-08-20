/// Riverpod provider wiring the goals repository to the app database.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/goals/repositories/saving_goal_repository.dart';
import 'package:money_pulse/infrastructure/goals/repositories/saving_goal_repository_sqflite.dart';

final savingGoalRepoProvider = Provider<SavingGoalRepository>((ref) {
  final db = ref.read(dbProvider);
  return SavingGoalRepositorySqflite(db);
});
