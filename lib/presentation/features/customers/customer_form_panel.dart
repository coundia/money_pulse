// CustomerFormPanel: create/update a customer with improved UX and Enter-to-save behavior.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/entities/company.dart';

import '../../../domain/company/repositories/company_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';

class CustomerFormPanel extends ConsumerStatefulWidget {
  final Customer? initial;
  const CustomerFormPanel({super.key, this.initial});

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
    return repo.findAll(const CompanyQuery(limit: 200, offset: 0));
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
    final base = Customer(
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
      addressLine1: null,
      addressLine2: null,
      city: null,
      region: null,
      country: null,
      postalCode: null,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: widget.initial?.version ?? 0,
      isDirty: true,
    );
    if (widget.initial == null) {
      await repo.create(base);
    } else {
      await repo.update(base);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  void _next(FocusNode node) {
    FocusScope.of(context).requestFocus(node);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
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
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(isEdit ? '' : ''),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: FutureBuilder<List<Company>>(
            future: _loadCompanies(),
            builder: (context, snap) {
              final companies = snap.data ?? const <Company>[];
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Form(
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        focusNode: _fCompany,
                        value: _companyId,
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
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TextFormField(
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
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}
