import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:jaayko/infrastructure/repositories/sync_state_repository_sqflite.dart';

final syncStateRepoProvider = Provider<SyncStateRepository>((ref) {
  final db = ref.read(dbProvider);
  return SyncStateRepositorySqflite(db);
});
