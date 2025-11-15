/* Riverpod providers to persist sync toggles in SharedPreferences and expose a SyncPolicy. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jaayko/sync/application/sync_policy.dart';
import 'package:jaayko/sync/domain/sync_domain.dart';

const _kDisabledDomains = 'sync_disabled_domains';

class SyncTogglesNotifier extends StateNotifier<Set<SyncDomain>> {
  SyncTogglesNotifier() : super(const {});

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_kDisabledDomains) ?? const <String>[];
    final set = <SyncDomain>{};
    for (final n in names) {
      final d = SyncDomain.values.where((e) => e.name == n);
      if (d.isNotEmpty) set.add(d.first);
    }
    state = set;
  }

  Future<void> setDisabled(SyncDomain d, bool disabled) async {
    final next = {...state};
    if (disabled) {
      next.add(d);
    } else {
      next.remove(d);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDisabledDomains,
      state.map((e) => e.name).toList(),
    );
  }

  Future<void> disableAll(Iterable<SyncDomain> domains) async {
    state = domains.toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDisabledDomains,
      state.map((e) => e.name).toList(),
    );
  }
}

final syncTogglesProvider =
    StateNotifierProvider<SyncTogglesNotifier, Set<SyncDomain>>(
      (ref) => SyncTogglesNotifier(),
    );

final syncPolicyProvider = Provider<SyncPolicy>((ref) {
  final disabled = ref.watch(syncTogglesProvider);
  return DisabledSetSyncPolicy(disabled);
});
