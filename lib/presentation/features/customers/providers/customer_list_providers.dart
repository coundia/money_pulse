// Providers for customer listing with search, company filter and only-active flag.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';

import '../../../app/providers/customer_repo_provider.dart';

final customerSearchProvider = StateProvider<String>((_) => '');
final customerCompanyFilterProvider = StateProvider<String?>((_) => null);
final customerOnlyActiveProvider = StateProvider<bool>((_) => true);
final customerPageSizeProvider = Provider<int>((_) => 30);
final customerPageIndexProvider = StateProvider<int>((_) => 0);

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.read(customerRepoProvider);
  final search = ref.watch(customerSearchProvider);
  final companyId = ref.watch(customerCompanyFilterProvider);
  final onlyActive = ref.watch(customerOnlyActiveProvider);
  final page = ref.watch(customerPageIndexProvider);
  final size = ref.watch(customerPageSizeProvider);
  return repo.findAll(
    CustomerQuery(
      search: search.trim().isEmpty ? null : search,
      companyId: (companyId ?? '').isEmpty ? null : companyId,
      limit: size,
      offset: page * size,
      onlyActive: onlyActive,
    ),
  );
});

final customerCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(customerRepoProvider);
  final search = ref.watch(customerSearchProvider);
  final companyId = ref.watch(customerCompanyFilterProvider);
  final onlyActive = ref.watch(customerOnlyActiveProvider);
  return repo.count(
    CustomerQuery(
      search: search.trim().isEmpty ? null : search,
      companyId: (companyId ?? '').isEmpty ? null : companyId,
      onlyActive: onlyActive,
    ),
  );
});
