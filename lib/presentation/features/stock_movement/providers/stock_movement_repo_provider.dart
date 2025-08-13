/// Riverpod provider wiring StockMovementRepository to AppDatabase.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import '../../../../infrastructure/stock/repositories/stock_movement_repository_sqflite.dart';
import '../../../../domain/stock/repositories/stock_movement_repository.dart';
import '../../../app/providers.dart';

final stockMovementRepoProvider = Provider<StockMovementRepository>((ref) {
  final db = ref.read(dbProvider);
  return StockMovementRepositorySqflite(db);
});
