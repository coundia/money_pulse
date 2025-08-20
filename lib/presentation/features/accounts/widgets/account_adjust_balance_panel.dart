// Right-drawer panel to adjust account balance; controller keeps cents (x100), preview shows major units.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../transactions/widgets/amount_field_quickpad.dart';

class AccountAdjustBalanceResult {
  final int newBalanceCents;
  const AccountAdjustBalanceResult(this.newBalanceCents);
}

class AccountAdjustBalancePanel extends StatefulWidget {
  final Account account;
  const AccountAdjustBalancePanel({super.key, required this.account});
  @override
  State<AccountAdjustBalancePanel> createState() =>
      _AccountAdjustBalancePanelState();
}

class _AccountAdjustBalancePanelState extends State<AccountAdjustBalancePanel> {
  late final TextEditingController _amountCtrl = TextEditingController(
    text: widget.account.balance == 0 ? '' : widget.account.balance.toString(),
  );

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    Navigator.pop(context, AccountAdjustBalanceResult(v));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final preview = Formatters.amountFromCents(
      int.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuster le solde'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Enregistrer')),
        ],
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _save();
                return null;
              },
            ),
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(
                  a.description?.isNotEmpty == true
                      ? a.description!
                      : (a.code ?? 'Compte'),
                ),
                subtitle: Text(a.currency ?? '—'),
                trailing: Text(
                  Formatters.amountFromCents(a.balance) +
                      (a.currency == null ? '' : ' ${a.currency}'),
                ),
              ),
              const SizedBox(height: 12),
              AmountFieldQuickPad(
                controller: _amountCtrl,
                quickUnits: const [
                  0,
                  2000,
                  5000,
                  10000,
                  20000,
                  50000,
                  100000,
                  200000,
                  300000,
                  400000,
                  500000,
                  1000000,
                ],
                lockToItems: false,
                onToggleLock: null,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'Aperçu: $preview ${a.currency ?? ''}'.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
