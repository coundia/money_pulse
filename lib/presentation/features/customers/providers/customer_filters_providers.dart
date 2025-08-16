// SRP: dedicated providers for list filters (search, company, hasDebt, paging).
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerSearchProvider = StateProvider<String>((_) => '');
final customerCompanyFilterProvider = StateProvider<String?>((_) => null);
final customerHasDebtFilterProvider = StateProvider<bool?>(
  (_) => null,
); // true: avec dette, false: sans dette, null: tous
final customerPageSizeProvider = Provider<int>((_) => 30);
final customerPageIndexProvider = StateProvider<int>((_) => 0);
