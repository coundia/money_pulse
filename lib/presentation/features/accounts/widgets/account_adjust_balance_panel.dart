// Simple panel to set a new balance for an account with Enter key submit and responsive layout.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';

class AccountAdjustBalanceResult {
  final int newBalanceCents;
  final String? note;
  const AccountAdjustBalanceResult({required this.newBalanceCents, this.note});
}

class AccountAdjustBalancePanel extends StatefulWidget {
  final Account account;
  const AccountAdjustBalancePanel({super.key, required this.account});

  @override
  State<AccountAdjustBalancePanel> createState() =>
      _AccountAdjustBalancePanelState();
}

class _AccountAdjustBalancePanelState extends State<AccountAdjustBalancePanel> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = (widget.account.balance ~/ 100).toString();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final units =
        int.tryParse(_amountCtrl.text.replaceAll(' ', '').trim()) ?? 0;
    final cents = units * 100;
    Navigator.pop(
      context,
      AccountAdjustBalanceResult(
        newBalanceCents: cents,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final currentText =
        '${Formatters.amountFromCents(a.balance)} ${a.currency ?? 'XOF'}';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ajuster le solde'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('Enregistrer')),
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
                _submit();
                return null;
              },
            ),
          },
          child: FocusTraversalGroup(
            child: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth >= 640;
                final form = Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.code ?? 'Compte',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Solde actuel: $currentText'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: wide
                              ? Row(
                                  children: [
                                    Expanded(child: _amountField()),
                                    const SizedBox(width: 12),
                                    Expanded(child: _noteField()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _amountField(),
                                    const SizedBox(height: 12),
                                    _noteField(),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.save),
                            label: const Text('Enregistrer'),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
                return SingleChildScrollView(child: form);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _amountField() {
    return TextFormField(
      controller: _amountCtrl,
      decoration: const InputDecoration(
        labelText: 'Nouveau solde (en F CFA)',
        helperText: 'Entrez le solde souhaité en unités. Ex: 150000',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Obligatoire';
        final n = int.tryParse(v.trim());
        if (n == null) return 'Nombre invalide';
        if (n < 0) return 'Doit être ≥ 0';
        return null;
      },
    );
  }

  Widget _noteField() {
    return TextFormField(
      controller: _noteCtrl,
      decoration: const InputDecoration(
        labelText: 'Note (optionnel)',
        border: OutlineInputBorder(),
      ),
      maxLines: 1,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }
}
