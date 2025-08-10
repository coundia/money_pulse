import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';

/// Holds the currently selected account id (null = use default account).
final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

/// Resolves the current Account: selected one if set, otherwise the default.
/// Also refreshes whenever transactions change so balance stays up-to-date.
final selectedAccountProvider = FutureProvider<Account?>((ref) async {
  final repo = ref.read(accountRepoProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);

  // 👇 re-fetch account whenever transactions change (balance likely changed)
  ref.watch(transactionsProvider);

  if (selectedId != null) {
    return repo.findById(selectedId);
  }
  return repo.findDefault();
});
