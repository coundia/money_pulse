// Riverpod bootstrap to run default seeds on app startup.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/company/usecases/seed_default_company_usecase.dart';
import 'package:money_pulse/domain/customer/usecases/seed_default_customer_usecase.dart';

import 'providers/company_repo_provider.dart';
import 'providers/customer_repo_provider.dart';

final seedDefaultCompanyUseCaseProvider = Provider<SeedDefaultCompanyUseCase>((
  ref,
) {
  final repo = ref.read(companyRepoProvider);
  return SeedDefaultCompanyUseCase(repo);
});

final seedDefaultCustomerUseCaseProvider = Provider<SeedDefaultCustomerUseCase>(
  (ref) {
    final customerRepo = ref.read(customerRepoProvider);
    final companyRepo = ref.read(companyRepoProvider);
    return SeedDefaultCustomerUseCase(customerRepo, companyRepo);
  },
);

final seedBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(seedDefaultCompanyUseCaseProvider).execute();
  await ref.read(seedDefaultCustomerUseCaseProvider).execute();
});
