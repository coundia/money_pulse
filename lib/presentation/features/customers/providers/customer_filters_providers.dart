// Filters state for customer list (search, company, hasDebt, sort, paging).
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CustomerSortMode { recent, az }

final customerSearchProvider = StateProvider<String>((_) => '');
final customerCompanyFilterProvider = StateProvider<String?>((_) => null);
final customerHasDebtFilterProvider = StateProvider<bool?>((_) => null);
final customerSortModeProvider = StateProvider<CustomerSortMode>(
  (_) => CustomerSortMode.recent,
);
final customerPageSizeProvider = Provider<int>((_) => 30);
final customerPageIndexProvider = StateProvider<int>((_) => 0);
