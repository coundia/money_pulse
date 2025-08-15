// Creates a default company if none exists (idempotent).
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';

class SeedDefaultCompanyUseCase {
  final CompanyRepository repo;
  SeedDefaultCompanyUseCase(this.repo);

  Future<String?> execute() async {
    final count = await repo.count(CompanyQuery(onlyActive: true, limit: 1));
    if (count > 0) return null;

    final now = DateTime.now();
    final company = Company(
      id: const Uuid().v4(),
      code: '',
      name: 'Main',
      description: 'Créée automatiquement',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
      version: 0,
      isDirty: true,
    );

    await repo.create(company);
    return company.id;
  }
}
