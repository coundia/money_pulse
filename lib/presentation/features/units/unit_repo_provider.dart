import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart'; // dbProvider
import 'package:money_pulse/domain/units/repositories/unit_repository.dart';
import 'package:money_pulse/infrastructure/repositories/unit_repository_sqflite.dart';

final unitRepoProvider = Provider<UnitRepository>((ref) {
  final db = ref.read(dbProvider);
  return UnitRepositorySqflite(db);
});
