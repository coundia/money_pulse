// Right-drawer form to add/edit an account with budgets, dates and type.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../transactions/widgets/amount_field_quickpad.dart';

class AccountFormResult {
  final String code;
  final String? description;
  final String? currency;
  final int? balanceInit;
  final int? balanceGoal;
  final int? balanceLimit;
  final String? typeAccount;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  const AccountFormResult({
    required this.code,
    this.description,
    this.currency,
    this.balanceInit,
    this.balanceGoal,
    this.balanceLimit,
    this.typeAccount,
    this.dateStart,
    this.dateEnd,
  });
}

class AccountFormPanel extends StatefulWidget {
  final Account? existing;
  const AccountFormPanel({super.key, this.existing});
  @override
  State<AccountFormPanel> createState() => _AccountFormPanelState();
}

class _AccountFormPanelState extends State<AccountFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _curr = TextEditingController(
    text: widget.existing?.currency ?? 'XOF',
  );
  late final TextEditingController _initCtrl = TextEditingController(
    text: (widget.existing?.balanceInit ?? 0).toString(),
  );
  late final TextEditingController _goalCtrl = TextEditingController(
    text: (widget.existing?.balanceGoal ?? 0).toString(),
  );
  late final TextEditingController _limitCtrl = TextEditingController(
    text: (widget.existing?.balanceLimit ?? 0).toString(),
  );

  static const _types = [
    'CASH',
    'BANK',
    'MOBILE',
    'SAVINGS',
    'CREDIT',
    'OTHER',
  ];
  String? _type;
  DateTime? _dateStart;
  DateTime? _dateEnd;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.typeAccount;
    _dateStart = widget.existing?.dateStartAccount;
    _dateEnd = widget.existing?.dateEndAccount;
  }

  @override
  void dispose() {
    _code.dispose();
    _desc.dispose();
    _curr.dispose();
    _initCtrl.dispose();
    _goalCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  int _parseAmount(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(' ', '')) ?? 0;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final base = _dateStart ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      initialDate: base,
      helpText: 'Date de début',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
      locale: const Locale('fr', 'FR'),
    );
    if (d != null)
      setState(() => _dateStart = DateTime(d.year, d.month, d.day, 0, 0));
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final base = _dateEnd ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
      initialDate: base,
      helpText: 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
      locale: const Locale('fr', 'FR'),
    );
    if (d != null)
      setState(() => _dateEnd = DateTime(d.year, d.month, d.day, 23, 59));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      AccountFormResult(
        code: _code.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        currency: _curr.text.trim().isEmpty ? null : _curr.text.trim(),
        balanceInit: _parseAmount(_initCtrl),
        balanceGoal: _parseAmount(_goalCtrl),
        balanceLimit: _parseAmount(_limitCtrl),
        typeAccount: _type,
        dateStart: _dateStart,
        dateEnd: _dateEnd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Modifier le compte' : 'Ajouter un compte'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _curr,
                  decoration: const InputDecoration(
                    labelText: 'Devise (ex. XOF)',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Text(
                  'Budgets & limites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(children: [Expanded(child: Text('Solde initial'))]),
                        AmountFieldQuickPad(
                          controller: _initCtrl,
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
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: Text('Objectif de solde')),
                          ],
                        ),
                        AmountFieldQuickPad(
                          controller: _goalCtrl,
                          quickUnits: const [
                            0,
                            50000,
                            100000,
                            200000,
                            300000,
                            500000,
                            1000000,
                            2000000,
                          ],
                          lockToItems: false,
                          onToggleLock: null,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [Expanded(child: Text('Limite de solde'))],
                        ),
                        AmountFieldQuickPad(
                          controller: _limitCtrl,
                          quickUnits: const [
                            0,
                            5000,
                            10000,
                            20000,
                            50000,
                            100000,
                            200000,
                            300000,
                            500000,
                          ],
                          lockToItems: false,
                          onToggleLock: null,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Période du compte',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickStart,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _dateStart == null
                                ? 'Date de début'
                                : Formatters.dateFull(_dateStart!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickEnd,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _dateEnd == null
                                ? 'Date de fin'
                                : Formatters.dateFull(_dateEnd!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Type de compte',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: _types
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t,
                          child: Text(
                            {
                              'CASH': 'Espèces',
                              'BANK': 'Banque',
                              'MOBILE': 'Mobile money',
                              'SAVINGS': 'Épargne',
                              'CREDIT': 'Crédit',
                              'OTHER': 'Autre',
                            }[t]!,
                          ),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Sélectionner',
                  ),
                  onChanged: (v) => setState(() => _type = v),
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
      ),
    );
  }
}
