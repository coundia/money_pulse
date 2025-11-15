/* Riverpod provider exposing the AccountUserRepository implementation. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/infrastructure/accounts/account_user_repository_sqflite.dart';
import 'package:jaayko/domain/accounts/repositories/account_user_repository.dart';

import '../../../app/providers.dart';

final accountUserRepoProvider = Provider<AccountUserRepository>((ref) {
  final db = ref.read(dbProvider).db;
  return AccountUserRepositorySqflite(db);
});
