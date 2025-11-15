// Riverpod provider wiring StockLevelRepository to AppDatabase/Sqflite

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/infrastructure/stock/repositories/stock_level_repository_sqflite.dart';
import 'package:jaayko/domain/stock/repositories/stock_level_repository.dart';

final stockLevelRepoProvider = Provider<StockLevelRepository>((ref) {
  final db = ref.read(dbProvider);
  return StockLevelRepositorySqflite(db);
});
