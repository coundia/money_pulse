import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/transactions/entities/transaction_entry.dart';
import 'package:jaayko/presentation/app/providers.dart';
import '../../../app/account_selection.dart';
import '../controllers/transaction_list_controller.dart';

final transactionListItemsProvider =
    FutureProvider.autoDispose<List<TransactionEntry>>((ref) async {
      final acc = await ref.watch(selectedAccountProvider.future);
      if (acc == null) return const <TransactionEntry>[];
      final state = ref.watch(transactionListStateProvider);
      final repo = ref.read(transactionRepoProvider);
      return repo.findByAccountBetween(
        acc.id,
        state.from,
        state.to,
        typeEntry: state.typeEntryString,
      );
    });
