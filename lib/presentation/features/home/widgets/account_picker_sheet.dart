// Compact bottom sheet to pick an account, with adjust-balance via right drawer and quick access to the Accounts page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_adjust_balance_panel.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/accounts/account_page.dart';

import '../../../app/account_selection.dart';

Future<Account?> showAccountPickerSheet({
  required BuildContext context,
  required Future<List<Account>> accountsFuture,
  required String? selectedAccountId,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocalState) {
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
                                  builder: (_) => const AccountPage(),
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

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(
                      leading: Icon(Icons.account_balance_wallet_outlined),
                      title: Text('Sélectionner un compte'),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (c, i) {
                          final a = all[i];
                          final isSelected = (selectedAccountId ?? '') == a.id;

                          return ListTile(
                            leading: const Icon(Icons.account_balance_wallet),
                            title: Text(
                              a.code ?? 'Compte',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: MoneyText(
                              amountCents: a.balance,
                              currency: a.currency ?? 'XOF',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) const Icon(Icons.check),
                                PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  onSelected: (value) async {
                                    if (value != 'adjust') return;
                                    final result =
                                        await showRightDrawer<
                                          AccountAdjustBalanceResult
                                        >(
                                          context,
                                          child: AccountAdjustBalancePanel(
                                            account: a,
                                          ),
                                          widthFraction: 0.64,
                                          heightFraction: 0.96,
                                        );
                                    if (result == null) return;
                                    try {
                                      final container =
                                          ProviderScope.containerOf(
                                            context,
                                            listen: false,
                                          );
                                      final repo = container.read(
                                        accountRepoProvider,
                                      );
                                      final updated = a.copyWith(
                                        balancePrev: a.balance,
                                        balance: result.newBalanceCents,
                                        updatedAt: DateTime.now(),
                                        isDirty: true,
                                      );
                                      await repo.update(updated);
                                      final ix = all.indexWhere(
                                        (x) => x.id == a.id,
                                      );
                                      if (ix != -1) all[ix] = updated;
                                      setLocalState(() {});
                                      try {
                                        await container
                                            .read(balanceProvider.notifier)
                                            .load();
                                      } catch (_) {}
                                      try {
                                        container.invalidate(
                                          selectedAccountProvider,
                                        );
                                        container.invalidate(
                                          accountRepoProvider,
                                        );
                                      } catch (_) {}
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Solde ajusté'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Échec de l’ajustement : $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'adjust',
                                      child: ListTile(
                                        leading: Icon(Icons.toll_outlined),
                                        title: Text('Ajuster le solde'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => Navigator.pop(c, a),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: all.length,
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
                                      builder: (_) => const AccountPage(),
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
                ),
              );
            },
          );
        },
      );
    },
  );
}
