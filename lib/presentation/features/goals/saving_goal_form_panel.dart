/// Right-drawer add/edit form for a savings goal with Enter-to-submit and amount quick pad.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/goals/entities/saving_goal.dart';
import 'package:money_pulse/domain/goals/repositories/saving_goal_repository.dart';
import 'package:money_pulse/presentation/features/goals/providers/saving_goal_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../transactions/widgets/amount_field_quickpad.dart';

class SavingGoalFormResult {
  final SavingGoal goal;
  final bool isNew;
  const SavingGoalFormResult(this.goal, this.isNew);
}

class SavingGoalFormPanel extends ConsumerStatefulWidget {
  final SavingGoal? existing;
  const SavingGoalFormPanel({super.key, this.existing});

  @override
  ConsumerState<SavingGoalFormPanel> createState() =>
      _SavingGoalFormPanelState();
}

class _SavingGoalFormPanelState extends ConsumerState<SavingGoalFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _targetViewCtrl;
  DateTime? _dueDate;
  int _targetCents = 0;
  int _priority = 3;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _targetCents = e?.targetCents ?? 0;
    _targetViewCtrl = TextEditingController(
      text: Formatters.amountFromCents(_targetCents),
    );
    _dueDate = e?.dueDate;
    _priority = e?.priority ?? 3;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _targetViewCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = _dueDate ?? now;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      initialDate: init,
      helpText: 'Choisir la date d’échéance',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      locale: const Locale('fr', 'FR'),
    );
    if (d != null) setState(() => _dueDate = d);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final repo = ref.read(savingGoalRepoProvider);
    final now = DateTime.now();

    if (widget.existing == null) {
      final e =
          SavingGoal.newDraft(
            name: _nameCtrl.text.trim(),
            targetCents: _targetCents,
            dueDate: _dueDate,
            priority: _priority,
          ).copyWith(
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          );
      await repo.insert(e);
      if (mounted) Navigator.of(context).pop(SavingGoalFormResult(e, true));
    } else {
      final e = widget.existing!.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        targetCents: _targetCents,
        dueDate: _dueDate,
        priority: _priority,
        updatedAt: now,
        isDirty: 1,
      );
      await repo.update(e);
      if (mounted) Navigator.of(context).pop(SavingGoalFormResult(e, false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.existing == null
                    ? 'Nouvel objectif'
                    : 'Modifier l’objectif',
              ),
              actions: [
                TextButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (_, c) {
                final isWide = c.maxWidth > 680;
                return SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nom de l’objectif',
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Champ obligatoire'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            AmountFieldQuickPad(
                              controller: _targetViewCtrl,
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
                              onChanged: () {
                                final raw = _targetViewCtrl.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                final cents = raw.isEmpty ? 0 : int.parse(raw);
                                setState(() => _targetCents = cents);
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickDate,
                                    icon: const Icon(Icons.event),
                                    label: Text(
                                      _dueDate == null
                                          ? 'Choisir l’échéance'
                                          : 'Échéance: ${Formatters.dateFull(_dueDate!)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DropdownButton<int>(
                                  value: _priority,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text('Priorité 1'),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text('Priorité 2'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('Priorité 3'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('Priorité 4'),
                                    ),
                                    DropdownMenuItem(
                                      value: 5,
                                      child: Text('Priorité 5'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _priority = v ?? 3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _submitting ? null : _submit,
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
