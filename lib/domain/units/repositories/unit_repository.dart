import 'package:money_pulse/domain/units/entities/unit.dart';

abstract class UnitRepository {
  Future<Unit> create(Unit unit);
  Future<void> update(Unit unit);

  Future<Unit?> findById(String id);
  Future<Unit?> findByCode(String code);

  Future<List<Unit>> findAllActive();
  Future<List<Unit>> searchActive(String query, {int limit = 200});

  Future<void> softDelete(String id);
}
