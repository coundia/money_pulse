/* Right-drawer panel listing all invited members with debounced search, enter-to-submit, pull-to-refresh, safe updatedAt-desc ordering, and per-member permissions (role changes & hard delete) restricted to the original inviter (username/phone). */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/app/connected_username_provider.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_list_providers.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_user_tile.dart';

class AccountUserListPanel extends ConsumerStatefulWidget {
  final String accountId;
  final String? accountName;
  const AccountUserListPanel({
    super.key,
    required this.accountId,
    this.accountName,
    required bool canManageRoles,
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

  String? _normalizePhone(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    final digitsPlus = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsPlus.startsWith('00')) return '+${digitsPlus.substring(2)}';
    if (!digitsPlus.startsWith('+') && digitsPlus.isNotEmpty)
      return '+$digitsPlus';
    return digitsPlus;
  }

  DateTime _sortKey(AccountUser m) {
    return (m.updatedAt ??
            m.createdAt ??
            m.invitedAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .toUtc();
  }

  bool _isCreator(
    AccountUser m, {
    required String? username,
    required String? phone,
  }) {
    final creator = m.createdBy?.trim();
    final cu = creator?.toLowerCase();
    final cp = _normalizePhone(creator);
    final un = username?.toLowerCase();
    final pn = _normalizePhone(phone);
    final userOk = cu != null && un != null && cu == un;
    final phoneOk = cp != null && pn != null && cp == pn;
    return userOk || phoneOk;
  }

  Future<void> _acceptMember(AccountUser m) async {
    try {
      final repo = ref.read(accountUserRepoProvider);
      await repo.accept(m.id);
      ref.invalidate(accountUserListProvider(widget.accountId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation acceptée')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Échec de l’acceptation')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(accountUserListProvider(widget.accountId));
    final title = widget.accountName == null
        ? 'Membres du compte'
        : 'Membres : ${widget.accountName}';

    final username = ref.watch(connectedUsernameProvider)?.toLowerCase();
    final phone = _normalizePhone(ref.watch(connectedPhoneProvider));

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _applySearch(_searchCtrl.text);
              return null;
            },
          ),
        },
        child: Scaffold(
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
                    onSubmitted: _applySearch,
                  ),
                ),
                Expanded(
                  child: listAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                      final sorted = [...members]
                        ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
                      final pending = sorted
                          .where(
                            (m) => (m.status ?? '').toUpperCase() == 'PENDING',
                          )
                          .length;
                      final accepted = sorted
                          .where(
                            (m) => (m.status ?? '').toUpperCase() == 'ACCEPTED',
                          )
                          .length;

                      if (sorted.isEmpty) {
                        return const Center(child: Text('Aucun membre'));
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                            accountUserListProvider(widget.accountId),
                          );
                          await Future.delayed(
                            const Duration(milliseconds: 220),
                          );
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    InputChip(
                                      isEnabled: false,
                                      avatar: const Icon(
                                        Icons.people_alt,
                                        size: 16,
                                      ),
                                      label: Text('Total : ${sorted.length}'),
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    InputChip(
                                      isEnabled: false,
                                      avatar: const Icon(
                                        Icons.check_circle,
                                        size: 16,
                                      ),
                                      label: Text('Acceptés : $accepted'),
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    InputChip(
                                      isEnabled: false,
                                      avatar: const Icon(
                                        Icons.hourglass_bottom,
                                        size: 16,
                                      ),
                                      label: Text('En attente : $pending'),
                                      visualDensity: const VisualDensity(
                                        horizontal: -2,
                                        vertical: -2,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                i,
                              ) {
                                final m = sorted[i];
                                final canManageThisMember = _isCreator(
                                  m,
                                  username: username,
                                  phone: phone,
                                );
                                final canHardDelete = canManageThisMember;

                                return Column(
                                  children: [
                                    AccountUserTile(
                                      member: m,
                                      onChanged: () => ref.invalidate(
                                        accountUserListProvider(
                                          widget.accountId,
                                        ),
                                      ),
                                      onAccept: _acceptMember,
                                      canManageRoles: canManageThisMember,
                                      onDelete: canHardDelete
                                          ? (u) async {
                                              final repo = ref.read(
                                                accountUserRepoProvider,
                                              );
                                              await repo.delete(u.id);
                                              ref.invalidate(
                                                accountUserListProvider(
                                                  widget.accountId,
                                                ),
                                              );
                                            }
                                          : null,
                                    ),
                                    if (i < sorted.length - 1)
                                      const Divider(height: 1),
                                  ],
                                );
                              }, childCount: sorted.length),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
