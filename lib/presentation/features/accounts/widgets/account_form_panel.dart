// Right-drawer form to add/edit an account; edit in major units, save in cents (x100), preview consistent in FR.
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
    text: (widget.existing?.balanceInit ?? 0) == 0
        ? ''
        : Formatters.majorRawFromMinor(
            widget.existing!.balanceInit!,
            decimals: 0,
          ),
  );
  late final TextEditingController _goalCtrl = TextEditingController(
    text: (widget.existing?.balanceGoal ?? 0) == 0
        ? ''
        : Formatters.majorRawFromMinor(
            widget.existing!.balanceGoal!,
            decimals: 0,
          ),
  );
  late final TextEditingController _limitCtrl = TextEditingController(
    text: (widget.existing?.balanceLimit ?? 0) == 0
        ? ''
        : Formatters.majorRawFromMinor(
            widget.existing!.balanceLimit!,
            decimals: 0,
          ),
  );

  static const _types = [
    'CASH',
    'BANK',
    'MOBILE',
    'SAVINGS',
    'CREDIT',
    'BUDGET_MAX',
    'OTHER',
  ];
  static const _typeIcons = {
    'CASH': Icons.payments_outlined,
    'BANK': Icons.account_balance,
    'MOBILE': Icons.smartphone,
    'SAVINGS': Icons.savings_outlined,
    'CREDIT': Icons.credit_card,
    'BUDGET_MAX': Icons.flag_circle_outlined,
    'OTHER': Icons.wallet_outlined,
  };
  static const _typeLabelsFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget maximum',
    'OTHER': 'Autre',
  };

  String? _type;
  DateTime? _dateStart;
  DateTime? _dateEnd;
  bool _useInit = false;
  bool _useGoal = false;
  bool _useLimit = false;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.typeAccount;
    _dateStart = widget.existing?.dateStartAccount;
    _dateEnd = widget.existing?.dateEndAccount;
    _useInit = (widget.existing?.balanceInit ?? 0) > 0;
    _useGoal = (widget.existing?.balanceGoal ?? 0) > 0;
    _useLimit = (widget.existing?.balanceLimit ?? 0) > 0;
    _applyTypeDefaults(force: true);
  }

  void _applyTypeDefaults({bool force = false}) {
    if (_type == 'BUDGET_MAX') {
      _useInit = false;
      _useGoal = false;
      _useLimit = true;
    } else if (_type == 'CREDIT') {
      _useLimit = true;
    }
  }

  int? _toMinorOpt(TextEditingController c, bool enabled) {
    if (!enabled) return null;
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return Formatters.toMinorFromMajorString(t);
  }

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
    if (d != null) {
      setState(() => _dateStart = DateTime(d.year, d.month, d.day, 0, 0));
    }
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
    if (d != null) {
      setState(() => _dateEnd = DateTime(d.year, d.month, d.day, 23, 59));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      AccountFormResult(
        code: _code.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        currency: _curr.text.trim().isEmpty ? null : _curr.text.trim(),
        balanceInit: _toMinorOpt(_initCtrl, _useInit),
        balanceGoal: _toMinorOpt(_goalCtrl, _useGoal),
        balanceLimit: _toMinorOpt(_limitCtrl, _useLimit),
        typeAccount: _type,
        dateStart: _dateStart,
        dateEnd: _dateEnd,
      ),
    );
  }

  String _goalLabel() {
    if (_type == 'SAVINGS') return 'Objectif d’épargne';
    if (_type == 'CREDIT') return 'Objectif de remboursement';
    return 'Objectif de solde';
  }

  String _limitLabel() {
    if (_type == 'CREDIT') return 'Plafond de crédit';
    if (_type == 'BUDGET_MAX') return 'Budget maximum';
    return 'Limite de solde';
  }

  Widget _amountBlock({
    required String title,
    required TextEditingController controller,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    bool forceOn = false,
    String? currency,
  }) {
    final centsPreview = Formatters.toMinorFromMajorString(controller.text);
    final preview = Formatters.amountFromCents(centsPreview);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: enabled || forceOn,
              onChanged: forceOn ? null : (v) => onToggle(v),
              title: Text(title),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: (enabled || forceOn) ? 1 : 0.35,
              child: IgnorePointer(
                ignoring: !(enabled || forceOn),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmountFieldQuickPad(
                      controller: controller,
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
                    const SizedBox(height: 6),
                    Text(
                      'Aperçu: $preview ${currency ?? ''}'.trim(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    final typeChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types
          .map(
            (t) => ChoiceChip(
              selected: _type == t,
              onSelected: (sel) {
                setState(() {
                  _type = sel ? t : null;
                  _applyTypeDefaults();
                });
              },
              avatar: Icon(_typeIcons[t], size: 18),
              label: Text(_typeLabelsFr[t]!),
            ),
          )
          .toList(),
    );

    final showInit = _type != 'BUDGET_MAX';
    final showGoal = _type != 'BUDGET_MAX';
    final forceLimit = _type == 'CREDIT' || _type == 'BUDGET_MAX';

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
          LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
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
                  'Type de compte',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                typeChips,
                const SizedBox(height: 16),
                Text(
                  'Budgets & limites',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (showInit)
                  _amountBlock(
                    title: 'Solde initial',
                    controller: _initCtrl,
                    enabled: _useInit,
                    onToggle: (v) => setState(() => _useInit = v),
                    currency: _curr.text.trim().isEmpty
                        ? null
                        : _curr.text.trim(),
                  ),
                if (showInit) const SizedBox(height: 8),
                if (showGoal)
                  _amountBlock(
                    title: _goalLabel(),
                    controller: _goalCtrl,
                    enabled: _useGoal,
                    onToggle: (v) => setState(() => _useGoal = v),
                    currency: _curr.text.trim().isEmpty
                        ? null
                        : _curr.text.trim(),
                  ),
                if (showGoal) const SizedBox(height: 8),
                _amountBlock(
                  title: _limitLabel(),
                  controller: _limitCtrl,
                  enabled: _useLimit,
                  onToggle: (v) => setState(() => _useLimit = v),
                  forceOn: forceLimit,
                  currency: _curr.text.trim().isEmpty
                      ? null
                      : _curr.text.trim(),
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
