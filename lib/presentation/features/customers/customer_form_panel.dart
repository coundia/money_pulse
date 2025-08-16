// Customer create/update form with responsive layout, small AppBar action to avoid overflow, and enter-to-save.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../../widgets/right_drawer.dart';
import 'widgets/customer_balance_adjust_panel.dart';
import '../../../domain/company/repositories/company_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';

class CustomerFormPanel extends ConsumerStatefulWidget {
  final Customer? initial;
  final String? initialCompanyId;
  const CustomerFormPanel({super.key, this.initial, this.initialCompanyId});

  @override
  ConsumerState<CustomerFormPanel> createState() => _CustomerFormPanelState();
}

class _CustomerFormPanelState extends ConsumerState<CustomerFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _full = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _status = TextEditingController();
  final _notes = TextEditingController();

  late final FocusNode _fCode;
  late final FocusNode _fFirst;
  late final FocusNode _fLast;
  late final FocusNode _fFull;
  late final FocusNode _fCompany;
  late final FocusNode _fPhone;
  late final FocusNode _fEmail;
  late final FocusNode _fStatus;
  late final FocusNode _fNotes;

  String? _companyId;

  @override
  void initState() {
    super.initState();
    _fCode = FocusNode();
    _fFirst = FocusNode();
    _fLast = FocusNode();
    _fFull = FocusNode();
    _fCompany = FocusNode();
    _fPhone = FocusNode();
    _fEmail = FocusNode();
    _fStatus = FocusNode();
    _fNotes = FocusNode();

    final c = widget.initial;
    if (c != null) {
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

    if (widget.initial == null && (widget.initialCompanyId ?? '').isNotEmpty) {
      _companyId = widget.initialCompanyId;
    }
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
    if (mounted && widget.initial == null) {
      if (_companyId == null || !_containsCompanyId(companies, _companyId)) {
        Company? def;
        try {
          def = companies.firstWhere((c) => c.isDefault == true);
        } catch (_) {
          def = companies.isNotEmpty ? companies.first : null;
        }
        if (def != null) {
          setState(() => _companyId = def!.id);
        }
      }
    }
    return companies;
  }

  String? _validateEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    return ok ? null : 'Email invalide';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(customerRepoProvider);
    final now = DateTime.now();
    final entity = Customer(
      id: widget.initial?.id ?? const Uuid().v4(),
      remoteId: widget.initial?.remoteId,
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
      addressLine1: widget.initial?.addressLine1,
      addressLine2: widget.initial?.addressLine2,
      city: widget.initial?.city,
      region: widget.initial?.region,
      country: widget.initial?.country,
      postalCode: widget.initial?.postalCode,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: widget.initial?.version ?? 0,
      isDirty: true,
      balance: widget.initial?.balance ?? 0,
      balanceDebt: widget.initial?.balanceDebt ?? 0,
    );
    if (widget.initial == null) {
      await repo.create(entity);
    } else {
      await repo.update(entity);
    }
    if (mounted) Navigator.of(context).pop<bool>(true);
  }

  void _next(FocusNode node) => FocusScope.of(context).requestFocus(node);

  bool _containsCompanyId(List<Company> list, String? id) {
    if (id == null || id.isEmpty) return false;
    for (final c in list) {
      if (c.id == id) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
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
            title: Text(isEdit ? 'Modifier le client' : 'Nouveau client'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: isEdit ? 'Enregistrer' : 'Créer',
                onPressed: _save,
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  const fieldGap = SizedBox(height: 12);

                  final left = <Widget>[
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
                    fieldGap,
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
                    fieldGap,
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
                            validator: _validateEmail,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => _next(_fStatus),
                          ),
                        ),
                      ],
                    ),
                    fieldGap,
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
                    fieldGap,
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
                  ];

                  final right = <Widget>[
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
                    fieldGap,
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
                    fieldGap,
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
                                      widget.initial?.balance ?? 0,
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
                                      widget.initial?.balanceDebt ?? 0,
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
                    fieldGap,
                    LayoutBuilder(
                      builder: (context, cts) {
                        final narrow = cts.maxWidth < 400;
                        if (widget.initial == null) {
                          return const SizedBox.shrink();
                        }
                        final addBtn = FilledButton.tonalIcon(
                          onPressed: () async {
                            final ok = await showRightDrawer<bool>(
                              context,
                              child: CustomerBalanceAdjustPanel(
                                customerId: widget.initial!.id,
                                currentBalanceCents: widget.initial!.balance,
                                companyId: widget.initial!.companyId,
                                mode: 'add',
                              ),
                              widthFraction: 0.86,
                              heightFraction: 0.96,
                            );
                            if (ok == true && context.mounted) {
                              Navigator.of(context).pop<bool>(true);
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
                                customerId: widget.initial!.id,
                                currentBalanceCents: widget.initial!.balance,
                                companyId: widget.initial!.companyId,
                                mode: 'set',
                              ),
                              widthFraction: 0.86,
                              heightFraction: 0.96,
                            );
                            if (ok == true && context.mounted) {
                              Navigator.of(context).pop<bool>(true);
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
                  ];

                  return Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: [...left])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(children: [...right])),
                            ],
                          )
                        else
                          Column(
                            children: [
                              ...left,
                              const SizedBox(height: 16),
                              ...right,
                            ],
                          ),
                        const SizedBox(height: 16),
                        SafeArea(
                          top: false,
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.check),
                            label: Text(isEdit ? 'Enregistrer' : 'Créer'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
