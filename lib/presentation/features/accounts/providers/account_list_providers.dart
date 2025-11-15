// Providers for account listing with search, type filter and updatedAt-desc ordering.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/presentation/features/accounts/account_repo_provider.dart';

final accountSearchProvider = StateProvider<String>((_) => '');
final accountTypeFilterProvider = StateProvider<String?>((_) => null);

final accountListProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.read(accountRepoProvider);
  final q = ref.watch(accountSearchProvider).trim().toLowerCase();
  final type = ref.watch(accountTypeFilterProvider);
  final items = await repo.findAllActive();
  final filtered = items.where((a) {
    final s = [
      a.code ?? '',
      a.description ?? '',
      a.currency ?? '',
      a.status ?? '',
      a.typeAccount ?? '',
    ].join(' ').toLowerCase();
    final okQ = q.isEmpty ? true : s.contains(q);
    final okT = (type == null || type.isEmpty) ? true : a.typeAccount == type;
    return okQ && okT;
  }).toList();
  filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return filtered;
});

final accountCountProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(accountListProvider.future);
  return list.length;
});
