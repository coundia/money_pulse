// Customer edit panel (SRP). Pops Customer? after save using popAfterFrame.
// Includes balance cards; optional adjust actions keep types consistent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/customer/entities/customer.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import '../../widgets/right_drawer.dart';
import 'widgets/customer_balance_adjust_panel.dart';
import '../../../domain/company/repositories/company_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import '../../shared/formatters.dart';
import 'customer_form_utils.dart';

class CustomerEditPanel extends ConsumerStatefulWidget {
  final Customer initial;
  const CustomerEditPanel({super.key, required this.initial});

  @override
  ConsumerState<CustomerEditPanel> createState() => _CustomerEditPanelState();
}

class _CustomerEditPanelState extends ConsumerState<CustomerEditPanel> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _full = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _status = TextEditingController();
  final _notes = TextEditingController();

  final _fCode = FocusNode();
  final _fFirst = FocusNode();
  final _fLast = FocusNode();
  final _fFull = FocusNode();
  final _fCompany = FocusNode();
  final _fPhone = FocusNode();
  final _fEmail = FocusNode();
  final _fStatus = FocusNode();
  final _fNotes = FocusNode();

  String? _companyId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _code.text = c.code ?? '';
    _first.text = c.firstName ?? '';
    _last.text = c.lastName ?? '';
    _full.text = c.fullName;
    _phone.text = c.phone ?? '';
    _email.text = c.email ?? '';
    _status.text = c.status ?? '';
    _notes.text = c.notes ?? '';
    _companyId = c.companyId;
  }

  @override
  void dispose() {
    _code.dispose();
    _first.dispose();
    _last.dispose();
    _full.dispose();
    _phone.dispose();
    _email.dispose();
    _status.dispose();
    _notes.dispose();
    _fCode.dispose();
    _fFirst.dispose();
    _fLast.dispose();
    _fFull.dispose();
    _fCompany.dispose();
    _fPhone.dispose();
    _fEmail.dispose();
    _fStatus.dispose();
    _fNotes.dispose();
    super.dispose();
  }

  Future<List<Company>> _loadCompanies() async {
    final repo = ref.read(companyRepoProvider);
    final companies = await repo.findAll(
      const CompanyQuery(limit: 200, offset: 0),
    );
    return companies;
  }

  bool _containsCompanyId(List<Company> list, String? id) =>
      id != null && id.isNotEmpty && list.any((c) => c.id == id);

  void _next(FocusNode node) => FocusScope.of(context).requestFocus(node);

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final repo = ref.read(customerRepoProvider);
    final now = DateTime.now();

    final entity = widget.initial.copyWith(
      code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      firstName: _first.text.trim().isEmpty ? null : _first.text.trim(),
      lastName: _last.text.trim().isEmpty ? null : _last.text.trim(),
      fullName: _full.text.trim().isEmpty
          ? [
              _first.text.trim(),
              _last.text.trim(),
            ].where((e) => e.isNotEmpty).join(' ')
          : _full.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      status: _status.text.trim().isEmpty ? null : _status.text.trim(),
      companyId: (_companyId ?? '').isEmpty ? null : _companyId,
      updatedAt: now,
      isDirty: true,
    );

    try {
      await repo.update(entity);
      if (!mounted) return;
      unawaited(safePop<Customer?>(context, entity));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = true;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: {
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Modifier le client'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  Navigator.of(context).maybePop(), // cancel -> null
            ),
            actions: [
              IconButton(
                tooltip: 'Enregistrer',
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
          body: FutureBuilder<List<Company>>(
            future: _loadCompanies(),
            builder: (context, snap) {
              final companies = snap.data ?? const <Company>[];
              final safeCompanyId = _containsCompanyId(companies, _companyId)
                  ? _companyId
                  : null;

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              const gap = SizedBox(height: 12);
              return AbsorbPointer(
                absorbing: _isSaving,
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              focusNode: _fFirst,
                              controller: _first,
                              decoration: const InputDecoration(
                                labelText: 'Prénom',
                                prefixIcon: Icon(Icons.person),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _next(_fLast),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              focusNode: _fLast,
                              controller: _last,
                              decoration: const InputDecoration(
                                labelText: 'Nom',
                                prefixIcon: Icon(Icons.person_outline),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _next(_fFull),
                            ),
                          ),
                        ],
                      ),
                      gap,
                      TextFormField(
                        focusNode: _fFull,
                        controller: _full,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet (sinon auto)',
                          prefixIcon: Icon(Icons.badge),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _next(_fPhone),
                      ),
                      gap,
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              focusNode: _fPhone,
                              controller: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                                prefixIcon: Icon(Icons.call),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _next(_fEmail),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              focusNode: _fEmail,
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: validateEmail,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _next(_fStatus),
                            ),
                          ),
                        ],
                      ),
                      gap,
                      TextFormField(
                        focusNode: _fStatus,
                        controller: _status,
                        decoration: const InputDecoration(
                          labelText: 'Statut',
                          prefixIcon: Icon(Icons.flag),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _next(_fNotes),
                      ),
                      gap,
                      DropdownButtonFormField<String?>(
                        key: ValueKey(safeCompanyId),
                        focusNode: _fCompany,
                        value: safeCompanyId,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Société',
                          prefixIcon: Icon(Icons.business),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Aucune —'),
                          ),
                          ...companies.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text('${c.name} (${c.code})'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _companyId = v),
                      ),
                      gap,
                      TextFormField(
                        focusNode: _fCode,
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          prefixIcon: Icon(Icons.qr_code_2),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _next(_fFirst),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),
                      gap,
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Solde'),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.amountFromCents(
                                        widget.initial.balance ?? 0,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Dette'),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.amountFromCents(
                                        widget.initial.balanceDebt ?? 0,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      gap,
                      LayoutBuilder(
                        builder: (context, cts) {
                          if (widget.initial.id.isEmpty)
                            return const SizedBox.shrink();
                          final narrow = cts.maxWidth < 400;

                          final addBtn = FilledButton.tonalIcon(
                            onPressed: () async {
                              final ok = await showRightDrawer<bool>(
                                context,
                                child: CustomerBalanceAdjustPanel(
                                  customerId: widget.initial.id,
                                  currentBalanceCents:
                                      widget.initial.balance ?? 0,
                                  companyId: widget.initial.companyId,
                                  mode: 'add',
                                ),
                                widthFraction: 0.86,
                                heightFraction: 0.96,
                              );
                              if (ok == true && context.mounted) {
                                unawaited(
                                  safePop<Customer?>(context, widget.initial),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Ajouter au solde'),
                          );

                          final setBtn = OutlinedButton.icon(
                            onPressed: () async {
                              final ok = await showRightDrawer<bool>(
                                context,
                                child: CustomerBalanceAdjustPanel(
                                  customerId: widget.initial.id,
                                  currentBalanceCents:
                                      widget.initial.balance ?? 0,
                                  companyId: widget.initial.companyId,
                                  mode: 'set',
                                ),
                                widthFraction: 0.86,
                                heightFraction: 0.96,
                              );
                              if (ok == true && context.mounted) {
                                safePop<Customer?>(context, widget.initial);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Définir le solde'),
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                addBtn,
                                const SizedBox(height: 8),
                                setBtn,
                              ],
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [addBtn, setBtn],
                          );
                        },
                      ),
                      gap,
                      TextFormField(
                        focusNode: _fNotes,
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 16),
                      SafeArea(
                        top: false,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
