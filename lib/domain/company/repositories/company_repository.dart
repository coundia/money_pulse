/* Company repository abstraction with sync-aware update. */
import 'package:jaayko/domain/company/entities/company.dart';

class CompanyQuery {
  final String? search;
  final int limit;
  final int offset;
  final bool onlyActive;
  const CompanyQuery({
    this.search,
    this.limit = 50,
    this.offset = 0,
    this.onlyActive = true,
  });
}

abstract class CompanyRepository {
  Future<Company?> findById(String id);
  Future<Company?> findByCode(String code);
  Future<Company?> findDefault();
  Future<List<Company>> findAll(CompanyQuery q);
  Future<int> count(CompanyQuery q);

  Future<String> create(Company c);
  Future<void> update(Company c);
  Future<void> softDelete(String id, {DateTime? at});
  Future<void> restore(String id);

  Future<void> updateFromSync(Company c);
}
