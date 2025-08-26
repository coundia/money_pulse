/// Riverpod providers to manage query and list of StockMovement rows.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/stock/repositories/stock_movement_repository.dart';
import 'stock_movement_repo_provider.dart';

final stockMovementQueryProvider = StateProvider<String>((ref) => '');

final stockMovementListProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(stockMovementRepoProvider);
  final q = ref.watch(stockMovementQueryProvider);
  return repo.search(query: q);
});
