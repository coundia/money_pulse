// lib/presentation/features/accounts/account_list_page.dart
// Orchestrates accounts list; marks rows as "Partagé" when the connected user isn't the creator (heuristic via account_users membership).
// FR labels, EN code. Long-press opens the context menu; highlights default account; clearable search & filter chips.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/app/providers.dart'
    hide accountRepoProvider;
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';

import 'account_repo_provider.dart';
import 'account_share_screen.dart';
import 'providers/account_list_providers.dart';
import 'widgets/account_tile.dart';
import 'widgets/account_context_menu.dart';
import 'widgets/account_details_panel.dart';
import 'widgets/account_form_panel.dart';
import 'widgets/account_adjust_balance_panel.dart';

import 'package:money_pulse/presentation/app/connected_username_provider.dart';
import 'providers/account_user_repo_provider.dart';

// >>> NEW: marketplace repo import
import 'account_marketplace_repo.dart';

class AccountListPage extends ConsumerStatefulWidget {
  const AccountListPage({super.key});
  @override
  ConsumerState<AccountListPage> createState() => _AccountListPageState();
}

class _AccountListPageState extends ConsumerState<AccountListPage> {
  late final AccountRepository _repo = ref.read(accountRepoProvider);
  final _searchCtrl = TextEditingController();

  final Map<String, bool> _isCreatorCache = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(accountSearchProvider);
    _searchCtrl.addListener(() {
      ref.read(accountSearchProvider.notifier).state = _searchCtrl.text;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtMoney(int cents, String? code) {
    final a = Formatters.amountFromCents(cents);
    return code == null ? a : '$a $code';
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : Formatters.dateShort(d);

  Future<void> _addOrEdit({Account? existing}) async {
    final res = await showRightDrawer<AccountFormResult>(
      context,
      child: AccountFormPanel(existing: existing),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (res == null) return;

    if (existing == null) {
      final now = DateTime.now();
      final acc = Account(
        id: const Uuid().v4(),
        remoteId: null,
        balance: res.balanceInit ?? 0,
        balancePrev: 0,
        balanceBlocked: 0,
        balanceInit: res.balanceInit ?? 0,
        balanceGoal: res.balanceGoal ?? 0,
        balanceLimit: res.balanceLimit ?? 0,
        code: res.code,
        description: res.description?.trim().isNotEmpty == true
            ? res.description
            : null,
        status: null,
        currency: res.currency?.trim().isNotEmpty == true ? res.currency : null,
        typeAccount: res.typeAccount,
        dateStartAccount: res.dateStart,
        dateEndAccount: res.dateEnd,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: true,
      );
      await _repo.create(acc);
    } else {
      final updated = existing.copyWith(
        code: res.code,
        description: res.description?.trim().isNotEmpty == true
            ? res.description
            : null,
        currency: res.currency?.trim().isNotEmpty == true ? res.currency : null,
        typeAccount: res.typeAccount,
        dateStartAccount: res.dateStart,
        dateEndAccount: res.dateEnd,
        balanceInit: res.balanceInit ?? existing.balanceInit,
        balanceGoal: res.balanceGoal ?? existing.balanceGoal,
        balanceLimit: res.balanceLimit ?? existing.balanceLimit,
        updatedAt: DateTime.now(),
      );
      await _repo.update(updated);
    }
    ref.invalidate(accountListProvider);
    if (mounted) setState(() {});
  }

  Future<void> _setDefault(Account acc) async {
    try {
      await _repo.setDefault(acc.id);
    } catch (_) {
      await _repo.update(acc.copyWith(isDefault: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastAccountIdKey, acc.id);
    ref.read(selectedAccountIdProvider.notifier).state = acc.id;
    ref.invalidate(accountListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('« ${acc.code} » est désormais le compte par défaut'),
      ),
    );
  }

  // >>> NEW: remote pull + local reconcile
  Future<void> _syncWithServer() async {
    try {
      final market = ref.read(
        accountMarketplaceRepoProvider('http://127.0.0.1:8095'),
      );
      final n = await market.pullAndReconcileList();
      ref.invalidate(accountListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synchronisation terminée ($n mis à jour)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de synchro: $e')));
    }
  }

  // >>> UPDATED: delete remote (if possible) then soft delete local
  Future<void> _delete(Account acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: Text('« ${acc.code ?? 'Compte'} » sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final hasRemote =
            (acc.remoteId?.trim().isNotEmpty == true) ||
            ((acc.code ?? '').trim().isNotEmpty);
        if (hasRemote) {
          final market = ref.read(
            accountMarketplaceRepoProvider('http://127.0.0.1:8095'),
          );
          await market.deleteRemoteThenLocal(acc);
        } else {
          await _repo.softDelete(acc.id);
        }
        ref.invalidate(accountListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('« ${acc.code ?? 'Compte'} » supprimé.')),
          );
          setState(() {});
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
      }
    }
  }

  Future<void> _share(Account a) async {
    await openAccountShareScreen<void>(
      context,
      accountId: a.id,
      accountName: a.code ?? 'Compte',
    );
  }

  Future<void> _adjustBalance(Account acc) async {
    final result = await showRightDrawer<AccountAdjustBalanceResult>(
      context,
      child: AccountAdjustBalancePanel(account: acc),
      widthFraction: 0.64,
      heightFraction: 0.96,
    );
    if (result == null) return;
    final updated = acc.copyWith(
      balancePrev: acc.balance,
      balance: result.newBalanceCents,
      updatedAt: DateTime.now(),
      isDirty: true,
    );
    await _repo.update(updated);
    ref.invalidate(accountListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Solde ajusté à ${_fmtMoney(updated.balance, updated.currency)}',
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _view(Account a) async {
    await showRightDrawer<void>(
      context,
      child: AccountDetailsPanel(
        account: a,
        onEdit: () => _addOrEdit(existing: a),
        onMakeDefault: () => _setDefault(a),
        onDelete: () => _delete(a),
        onShare: () => _share(a),
        onSaveRemote: () async {
          final market = ref.read(
            accountMarketplaceRepoProvider('http://127.0.0.1:8095'),
          );
          await market.saveAndReconcile(a);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Compte synchronisé avec le serveur'),
              ),
            );
          }
          // Rafraîchir la liste ou l’item
          ref.invalidate(accountListProvider);
        },
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
  }

  Future<bool> _inferIsCreator(String accountId) async {
    final me = ref.read(connectedUsernameProvider);
    if (me == null || me.trim().isEmpty) return true;

    final cached = _isCreatorCache[accountId];
    if (cached != null) return cached;

    try {
      final repo = ref.read(accountUserRepoProvider);
      final rows = await repo.listByAccount(accountId, q: me);
      final meL = me.trim().toLowerCase();

      bool isMe(AccountUser u) {
        final i = (u.identity ?? '').trim().toLowerCase();
        final u1 = (u.user ?? '').trim().toLowerCase();
        final e = (u.email ?? '').trim().toLowerCase();
        return i == meL || u1 == meL || e == meL;
      }

      final mine = rows.where(isMe).toList();
      if (mine.isEmpty) {
        _isCreatorCache[accountId] = true;
        return true;
      }

      final shared = mine.any((m) {
        final by = (m.invitedBy ?? m.createdBy)?.trim().toLowerCase();
        return by == null || by != meL;
      });

      final isCreator = !shared;
      _isCreatorCache[accountId] = isCreator;
      return isCreator;
    } catch (_) {
      _isCreatorCache[accountId] = true;
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(accountListProvider);
    final count = ref
        .watch(accountCountProvider)
        .maybeWhen(orElse: () => 0, data: (v) => v);
    final selectedType = ref.watch(accountTypeFilterProvider);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par code, devise, description, type',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: (_searchCtrl.text.isEmpty)
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.clear),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => ref.invalidate(accountListProvider),
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Filtrer',
                onSelected: (v) =>
                    ref.read(accountTypeFilterProvider.notifier).state =
                        v == 'ALL' ? null : v,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'ALL', child: Text('Tous les types')),
                  PopupMenuItem(value: 'CASH', child: Text('Espèces')),
                  PopupMenuItem(value: 'BANK', child: Text('Banque')),
                  PopupMenuItem(value: 'MOBILE', child: Text('Mobile money')),
                  PopupMenuItem(value: 'SAVINGS', child: Text('Épargne')),
                  PopupMenuItem(value: 'CREDIT', child: Text('Crédit')),
                  PopupMenuItem(
                    value: 'BUDGET_MAX',
                    child: Text('Budget maximum'),
                  ),
                  PopupMenuItem(value: 'OTHER', child: Text('Autre')),
                ],
                child: Chip(
                  avatar: const Icon(Icons.filter_alt, size: 18),
                  label: Text(
                    selectedType == null
                        ? 'Filtres ($count)'
                        : 'Filtre: $selectedType ($count)',
                  ),
                ),
              ),
            ],
          ),
          if (selectedType != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  label: Text('Type: $selectedType'),
                  onDeleted: () =>
                      ref.read(accountTypeFilterProvider.notifier).state = null,
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes'),
        actions: [
          IconButton(
            onPressed: () => _addOrEdit(),
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter un compte',
          ),
          IconButton(
            onPressed: _syncWithServer, // <<< NEW
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Synchroniser',
          ),
          IconButton(
            onPressed: () => ref.invalidate(accountListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un compte'),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: [header, _empty()]);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) =>
                  i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
              itemBuilder: (_, i) {
                if (i == 0) return header;
                final a = items[i - 1];
                return _accountRow(a);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _accountRow(Account a) {
    final theme = Theme.of(context);
    final isDefault = a.isDefault;

    // ensure a non-nullable Future<bool> for FutureBuilder<bool>
    final Future<bool> fut = _isCreatorCache.containsKey(a.id)
        ? Future<bool>.value(_isCreatorCache[a.id]!)
        : _inferIsCreator(a.id);

    final decorated = FutureBuilder<bool>(
      future: fut,
      builder: (context, snap) {
        final isCreator = snap.data ?? true;
        final tile = AccountTile(
          key: ValueKey('tile_${a.id}'),
          account: a,
          balanceText: _fmtMoney(a.balance, a.currency),
          updatedAtText: _fmtDate(a.updatedAt),
          isCreator: isCreator,
          onView: () => _view(a),
        );

        final base = Container(
          key: ValueKey(a.id),
          decoration: isDefault
              ? BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.035),
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                  ),
                )
              : null,
          child: tile,
        );

        final content = isDefault
            ? Stack(
                children: [
                  base,
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Tooltip(
                      message: 'Compte par défaut',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Défaut',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : base;

        return GestureDetector(
          key: ValueKey('row_${a.id}'),
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (d) {
            showAccountContextMenu(
              context,
              d.globalPosition,
              canMakeDefault: !a.isDefault,
              onView: () => _view(a),
              onMakeDefault: () => _setDefault(a),
              onEdit: () => _addOrEdit(existing: a),
              onDelete: () => _delete(a),
              onShare: () => _share(a),
              onAdjustBalance: () => _adjustBalance(a),
              accountLabel: a.code,
              balanceCents: a.balance,
              currency: a.currency,
              updatedAt: a.updatedAt,
            );
          },
          child: content,
        );
      },
    );

    return decorated;
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_outlined, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucun compte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Créez votre premier compte pour suivre vos soldes.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
