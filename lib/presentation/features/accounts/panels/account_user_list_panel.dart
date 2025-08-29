/* Right-drawer panel listing all invited members with debounced search, per-member role permission (inviter username/phone), keyboard shortcuts, pull-to-refresh, and safe updatedAt-desc ordering. */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/presentation/app/connected_username_provider.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_list_providers.dart';
import 'package:money_pulse/presentation/features/accounts/providers/account_user_repo_provider.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_user_tile.dart';

import '../../../../onboarding/presentation/providers/access_session_provider.dart';

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
                            SliverList.separated(
                              itemCount: sorted.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final m = sorted[i];
                                final createdBy = m.createdBy?.trim();
                                final createdByPhone = _normalizePhone(
                                  createdBy,
                                );
                                final accessGrant = ref.read(
                                  accessSessionProvider,
                                );
                                final createdByL = accessGrant?.username;

                                final canManageThisMember =
                                    (createdByL != null &&
                                        username != null &&
                                        createdByL == username) ||
                                    (createdByPhone != null &&
                                        phone != null &&
                                        createdByPhone == phone);

                                return AccountUserTile(
                                  member: m,
                                  onChanged: () => ref.invalidate(
                                    accountUserListProvider(widget.accountId),
                                  ),
                                  onAccept: _acceptMember,
                                  canManageRoles: canManageThisMember,
                                );
                              },
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
