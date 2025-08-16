// List and count providers using SRP filters, sort mode, and updated sort by updatedAt DESC.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';
import '../../../app/providers/customer_repo_provider.dart';
import 'customer_filters_providers.dart';

final customerListProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.read(customerRepoProvider);
  final search = ref.watch(customerSearchProvider);
  final companyId = ref.watch(customerCompanyFilterProvider);
  final hasDebt = ref.watch(customerHasDebtFilterProvider);
  final sortMode = ref.watch(customerSortModeProvider);
  final page = ref.watch(customerPageIndexProvider);
  final size = ref.watch(customerPageSizeProvider);

  final orderByUpdated = sortMode == CustomerSortMode.recent;

  return repo.findAll(
    CustomerQuery(
      search: search.trim().isEmpty ? null : search,
      companyId: (companyId ?? '').isEmpty ? null : companyId,
      hasOpenDebt: hasDebt,
      limit: size,
      offset: page * size,
      onlyActive: true,
      orderByUpdatedAtDesc: orderByUpdated,
    ),
  );
});

final customerCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(customerRepoProvider);
  final search = ref.watch(customerSearchProvider);
  final companyId = ref.watch(customerCompanyFilterProvider);
  final hasDebt = ref.watch(customerHasDebtFilterProvider);
  return repo.count(
    CustomerQuery(
      search: search.trim().isEmpty ? null : search,
      companyId: (companyId ?? '').isEmpty ? null : companyId,
      hasOpenDebt: hasDebt,
      onlyActive: true,
    ),
  );
});
