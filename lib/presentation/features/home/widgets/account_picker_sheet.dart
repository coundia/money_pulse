import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';

/// Ouvre un bottom-sheet listant les comptes et retourne le compte choisi.
Future<Account?> showAccountPickerSheet({
  required BuildContext context,
  required Future<List<Account>> accountsFuture,
  required String? selectedAccountId,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    builder: (ctx) => SafeArea(
      child: FutureBuilder<List<Account>>(
        future: accountsFuture,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final accounts = snap.data ?? const <Account>[];
          if (accounts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No accounts'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemBuilder: (c, i) {
              final a = accounts[i];
              final isSelected = (selectedAccountId ?? '') == a.id;
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(a.code ?? ''),
                subtitle: MoneyText(
                  amountCents: a.balance,
                  currency: a.currency ?? 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, a),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: accounts.length,
          );
        },
      ),
    ),
  );
}
