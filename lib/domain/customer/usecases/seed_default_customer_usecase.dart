// Creates a default customer if none exists (idempotent), linked to a company when available.
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';

class SeedDefaultCustomerUseCase {
  final CustomerRepository customerRepo;
  final CompanyRepository companyRepo;
  SeedDefaultCustomerUseCase(this.customerRepo, this.companyRepo);

  Future<String?> execute() async {
    final count = await customerRepo.count(
      CustomerQuery(onlyActive: true, limit: 1),
    );
    if (count > 0) return null;

    String? companyId;
    final companies = await companyRepo.findAll(
      CompanyQuery(onlyActive: true, limit: 1),
    );
    if (companies.isNotEmpty) {
      companyId = companies.first.id;
    }

    final now = DateTime.now();
    final customer = Customer(
      id: const Uuid().v4(),
      code: 'ANNONYME',
      firstName: 'ANNONYME',
      lastName: '',
      fullName: 'ANNONYME',
      status: 'ACTIVE',
      companyId: companyId,
      createdAt: now,
      updatedAt: now,
      version: 0,
      isDirty: true,
    );

    await customerRepo.create(customer);
    return customer.id;
  }
}
