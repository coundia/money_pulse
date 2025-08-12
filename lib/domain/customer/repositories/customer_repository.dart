import 'package:money_pulse/domain/customer/entities/customer.dart';

class CustomerQuery {
  final String? search; // fullName/phone/email/code
  final String? companyId;
  final int? limit;
  final int? offset;
  final bool onlyActive;

  const CustomerQuery({
    this.search,
    this.companyId,
    this.limit,
    this.offset,
    this.onlyActive = true,
  });
}

abstract class CustomerRepository {
  Future<Customer?> findById(String id);
  Future<List<Customer>> findAll(CustomerQuery q);
  Future<int> count(CustomerQuery q);

  Future<String> create(Customer c);
  Future<void> update(Customer c);
  Future<void> softDelete(String id, {DateTime? at});
  Future<void> restore(String id);
}
