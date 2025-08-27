/* Right-drawer panel listing all invited members for an account with safe sorting by last update date. */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_list_providers.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_user_tile.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';

class AccountUserListPanel extends ConsumerStatefulWidget {
  final String accountId;
  final String? accountName;
  const AccountUserListPanel({
    super.key,
    required this.accountId,
    this.accountName,
  });

  @override
  ConsumerState<AccountUserListPanel> createState() =>
      _AccountUserListPanelState();
}

class _AccountUserListPanelState extends ConsumerState<AccountUserListPanel> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      ref.read(accountUserSearchProvider.notifier).state = v.trim();
    });
  }

  DateTime _sortKey(AccountUser m) {
    return (m.updatedAt ??
            m.createdAt ??
            m.invitedAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .toUtc();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(accountUserListProvider(widget.accountId));
    final title = widget.accountName == null
        ? 'Membres du compte'
        : 'Membres : ${widget.accountName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.numpadEnter):
                      ActivateIntent(),
                },
                child: Actions(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (e) {
                        _applySearch(_searchCtrl.text);
                        return null;
                      },
                    ),
                  },
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rechercher un membre',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _applySearch('');
                              },
                              icon: const Icon(Icons.clear),
                              tooltip: 'Effacer',
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _applySearch,
                  ),
                ),
              ),
            ),
            Expanded(
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Erreur de chargement'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => ref.invalidate(
                          accountUserListProvider(widget.accountId),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
                data: (members) {
                  if (members.isEmpty) {
                    return const Center(child: Text('Aucun membre'));
                  }
                  final sorted = [...members]
                    ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(accountUserListProvider(widget.accountId));
                      await Future.delayed(const Duration(milliseconds: 220));
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        return AccountUserTile(
                          member: sorted[i],
                          onChanged: () => ref.invalidate(
                            accountUserListProvider(widget.accountId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
