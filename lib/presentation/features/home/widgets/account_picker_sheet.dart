// Bottom sheet to pick an account; searchable list, type-aware tiles, inline adjust using AdjustBalanceUseCase.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/presentation/features/accounts/account_page.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';
import 'package:jaayko/presentation/features/accounts/widgets/account_adjust_balance_panel.dart';
import 'package:jaayko/application/providers/adjust_balance_usecase_provider.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/features/accounts/providers/account_list_providers.dart';

import '../../../app/account_selection.dart';
import 'account_picker_tile.dart';

Future<Account?> showAccountPickerSheet({
  required BuildContext context,
  required Future<List<Account>> accountsFuture,
  required String? selectedAccountId,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final searchCtrl = TextEditingController();
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              return FutureBuilder<List<Account>>(
                future: accountsFuture,
                builder: (c, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final all = List<Account>.of(snap.data ?? const <Account>[]);
                  if (all.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Aucun compte'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Future.microtask(() {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AccountListPage(),
                                    ),
                                  );
                                });
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Voir tous les comptes'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  all.sort((a, b) {
                    final da = a.updatedAt ?? a.createdAt ?? DateTime(1970);
                    final db = b.updatedAt ?? b.createdAt ?? DateTime(1970);
                    return db.compareTo(da);
                  });

                  String q = searchCtrl.text.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? all
                      : all.where((a) {
                          final t1 = (a.code ?? '').toLowerCase();
                          final t2 = (a.description ?? '').toLowerCase();
                          final t3 = (a.currency ?? '').toLowerCase();
                          final t4 = (a.typeAccount ?? '').toLowerCase();
                          return t1.contains(q) ||
                              t2.contains(q) ||
                              t3.contains(q) ||
                              t4.contains(q);
                        }).toList();

                  Future<void> _adjust(Account a) async {
                    final result =
                        await showRightDrawer<AccountAdjustBalanceResult>(
                          context,
                          child: AccountAdjustBalancePanel(account: a),
                          widthFraction: 0.64,
                          heightFraction: 0.96,
                        );
                    if (result == null) return;

                    final usecase = ref.read(adjustBalanceUseCaseProvider);
                    final updated = await usecase.execute(
                      account: a,
                      newBalanceCents: result.newBalanceCents,
                      userNote: null,
                    );

                    final ix = all.indexWhere((x) => x.id == a.id);
                    if (ix != -1) all[ix] = updated;
                    setLocal(() {});

                    try {
                      await ref.read(balanceProvider.notifier).load();
                    } catch (_) {}
                    ref.invalidate(selectedAccountProvider);
                    ref.invalidate(accountListProvider);

                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Solde ajusté et transaction créée'),
                        ),
                      );
                    }
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  }

                  return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.6,
                    minChildSize: 0.4,
                    maxChildSize: 0.92,
                    builder: (context, scrollCtrl) {
                      return Column(
                        children: [
                          const ListTile(
                            leading: Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            title: Text('Sélectionner un compte'),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: TextField(
                              controller: searchCtrl,
                              decoration: InputDecoration(
                                hintText:
                                    'Rechercher (code, description, devise, type)',
                                prefixIcon: const Icon(Icons.search),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setLocal(() {}),
                              onSubmitted: (_) => setLocal(() {}),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              itemBuilder: (c, i) {
                                final a = filtered[i];
                                final isSelected =
                                    (selectedAccountId ?? '') == a.id;

                                // ✅ Stable unique keys (based on id) so duplicate codes render separately.
                                return Container(
                                  key: ValueKey('picker_row_${a.id}'),
                                  child: AccountPickerTile(
                                    key: ValueKey('picker_tile_${a.id}'),
                                    account: a,
                                    isSelected: isSelected,
                                    onPick: () => Navigator.pop(c, a),
                                    onAdjust: () => _adjust(a),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemCount: filtered.length,
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Future.microtask(() {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AccountListPage(),
                                          ),
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Tous les comptes'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}
