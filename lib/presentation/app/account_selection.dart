import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clé utilisée dans SharedPreferences
const kLastAccountIdKey = 'last_account_id';

/// Holds the currently selected account id (null = use default account).
final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

/// Resolves the current Account: selected one if set, otherwise the default.
/// Also refreshes whenever transactions change so balance stays up-to-date.
final selectedAccountProvider = FutureProvider<Account?>((ref) async {
  final repo = ref.read(accountRepoProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);

  // re-fetch account whenever transactions change (balance likely changed)
  ref.watch(transactionsProvider);

  if (selectedId != null) {
    return repo.findById(selectedId);
  }
  return repo.findDefault();
});

/// Ensure we have a selected account at startup:
/// 1) essaie le dernier id sauvegardé
/// 2) sinon prend le compte par défaut
/// 3) sauvegarde l'id choisi
final ensureSelectedAccountProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final repo = ref.read(accountRepoProvider);

  // si déjà sélectionné, on vérifie qu'il existe encore et on persiste
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

  // 1) tenter l'ID sauvegardé
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

  // 2) fallback: compte par défaut
  final def = await repo.findDefault();
  if (def != null) {
    ref.read(selectedAccountIdProvider.notifier).state = def.id;
    // 3) persister
    await prefs.setString(kLastAccountIdKey, def.id);
  }
});
