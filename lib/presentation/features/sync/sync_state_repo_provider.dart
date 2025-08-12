import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/infrastructure/repositories/sync_state_repository_sqflite.dart';

final syncStateRepoProvider = Provider<SyncStateRepository>((ref) {
  final db = ref.read(dbProvider);
  return SyncStateRepositorySqflite(db);
});
