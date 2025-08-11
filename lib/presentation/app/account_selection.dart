import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLastAccountIdKey = 'last_account_id';

final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

final selectedAccountProvider = FutureProvider<Account?>((ref) async {
  final repo = ref.read(accountRepoProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);

  ref.watch(transactionsProvider);

  if (selectedId != null) {
    return repo.findById(selectedId);
  }
  return repo.findDefault();
});

final ensureSelectedAccountProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final repo = ref.read(accountRepoProvider);

  final current = ref.read(selectedAccountIdProvider);
  if (current != null && current.isNotEmpty) {
    final exists = await repo.findById(current);
    if (exists != null) {
      await prefs.setString(kLastAccountIdKey, current);
      return;
    } else {
      await prefs.remove(kLastAccountIdKey);
    }
  }

  final savedId = prefs.getString(kLastAccountIdKey);
  if (savedId != null && savedId.isNotEmpty) {
    final acc = await repo.findById(savedId);
    if (acc != null) {
      ref.read(selectedAccountIdProvider.notifier).state = savedId;
      return;
    } else {
      await prefs.remove(kLastAccountIdKey);
    }
  }

  final def = await repo.findDefault();
  if (def != null) {
    ref.read(selectedAccountIdProvider.notifier).state = def.id;
    await prefs.setString(kLastAccountIdKey, def.id);
  }
});
