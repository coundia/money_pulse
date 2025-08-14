// Compact bottom sheet to pick an account, always showing a "Voir plus/Voir moins" row and allowing balance adjust via right drawer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/accounts/widgets/account_adjust_balance_panel.dart';
import 'package:money_pulse/presentation/app/providers.dart';

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
      bool showAll = false;
      const initialCount = 6;

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
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aucun compte')),
                );
              }

              final visible = showAll ? all : all.take(initialCount).toList();

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
                          final a = visible[i];
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
                                      if (ix != -1) {
                                        all[ix] = updated;
                                      }
                                      setLocalState(() {});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Solde ajusté à ${updated.currency ?? 'XOF'}',
                                            ),
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
                        itemCount: visible.length,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(showAll ? 'Voir moins' : 'Voir plus'),
                      trailing: Icon(
                        showAll ? Icons.expand_less : Icons.expand_more,
                      ),
                      onTap: () => setLocalState(() => showAll = !showAll),
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
