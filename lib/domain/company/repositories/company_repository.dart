import 'package:money_pulse/domain/company/entities/company.dart';

class CompanyQuery {
  final String? search; // code/name/phone/email
  final int? limit;
  final int? offset;
  final bool onlyActive;

  const CompanyQuery({
    this.search,
    this.limit,
    this.offset,
    this.onlyActive = true,
  });
}

abstract class CompanyRepository {
  Future<Company?> findById(String id);
  Future<Company?> findDefault();
  Future<List<Company>> findAll(CompanyQuery q);
  Future<int> count(CompanyQuery q);

  Future<String> create(Company c);
  Future<void> update(Company c);
  Future<void> softDelete(String id, {DateTime? at});
  Future<void> restore(String id);
  Future<Company?> findByCode(String code);
}
