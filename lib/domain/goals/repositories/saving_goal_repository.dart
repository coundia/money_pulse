/// Repository abstraction and query object for savings goals.

import 'package:money_pulse/domain/goals/entities/saving_goal.dart';

class SavingGoalQuery {
  final String? search;
  final bool onlyActive;
  final bool? completed;
  final int? limit;
  final int? offset;

  const SavingGoalQuery({
    this.search,
    this.onlyActive = true,
    this.completed,
    this.limit,
    this.offset,
  });
}

abstract class SavingGoalRepository {
  Future<List<SavingGoal>> findAll(SavingGoalQuery q);
  Future<int> count(SavingGoalQuery q);
  Future<SavingGoal?> findById(String id);
  Future<void> insert(SavingGoal e);
  Future<void> update(SavingGoal e);
  Future<void> updatePartial(String id, Map<String, Object?> patch);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> addToSaved(String id, int deltaCents);
}
