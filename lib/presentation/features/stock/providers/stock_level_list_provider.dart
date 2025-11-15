// List/search providers for StockLevel list page

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/stock/repositories/stock_level_repository.dart';
import 'stock_level_repo_provider.dart';

final stockLevelQueryProvider = StateProvider<String>((ref) => '');

final stockLevelListProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(stockLevelRepoProvider);
  final q = ref.watch(stockLevelQueryProvider);
  return repo.search(query: q);
});
