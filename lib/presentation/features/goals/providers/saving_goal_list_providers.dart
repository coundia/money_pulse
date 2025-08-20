/// List providers for savings goals: search, filters, pagination and loaders.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/domain/goals/repositories/saving_goal_repository.dart';
import 'package:money_pulse/presentation/features/goals/providers/saving_goal_repo_provider.dart';

final savingGoalSearchProvider = StateProvider<String>((_) => '');
final savingGoalOnlyActiveProvider = StateProvider<bool>((_) => true);
final savingGoalOnlyCompletedProvider = StateProvider<bool?>((_) => null);
final savingGoalPageSizeProvider = Provider<int>((_) => 30);
final savingGoalPageIndexProvider = StateProvider<int>((_) => 0);

final savingGoalListProvider = FutureProvider<List<SavingGoal>>((ref) async {
  final repo = ref.read(savingGoalRepoProvider);
  final search = ref.watch(savingGoalSearchProvider);
  final onlyActive = ref.watch(savingGoalOnlyActiveProvider);
  final onlyCompleted = ref.watch(savingGoalOnlyCompletedProvider);
  final page = ref.watch(savingGoalPageIndexProvider);
  final size = ref.watch(savingGoalPageSizeProvider);

  return repo.findAll(
    SavingGoalQuery(
      search: search.trim().isEmpty ? null : search.trim(),
      onlyActive: onlyActive,
      completed: onlyCompleted,
      limit: size,
      offset: page * size,
    ),
  );
});

final savingGoalCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(savingGoalRepoProvider);
  final search = ref.watch(savingGoalSearchProvider);
  final onlyActive = ref.watch(savingGoalOnlyActiveProvider);
  final onlyCompleted = ref.watch(savingGoalOnlyCompletedProvider);

  return repo.count(
    SavingGoalQuery(
      search: search.trim().isEmpty ? null : search.trim(),
      onlyActive: onlyActive,
      completed: onlyCompleted,
    ),
  );
});
