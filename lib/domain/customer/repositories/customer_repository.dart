import 'package:jaayko/domain/customer/entities/customer.dart';

class CustomerQuery {
  final String? search;
  final String? companyId;
  final bool onlyActive;
  final int? limit;
  final int? offset;
  final bool? hasOpenDebt; // true: with debt, false: without, null: all
  final bool orderByUpdatedAtDesc;

  const CustomerQuery({
    this.search,
    this.companyId,
    this.onlyActive = true,
    this.limit,
    this.offset,
    this.hasOpenDebt,
    this.orderByUpdatedAtDesc = false,
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
