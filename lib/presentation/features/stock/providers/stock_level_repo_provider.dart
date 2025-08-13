// Riverpod provider wiring StockLevelRepository to Sqflite database

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/infrastructure/stock/repositories/stock_level_repository_sqflite.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';
import 'package:sqflite_common/sqlite_api.dart';

final stockLevelRepoProvider = Provider<StockLevelRepository>((ref) {
  final db = ref.read(dbProvider);
  return StockLevelRepositorySqflite(db as Database);
});
