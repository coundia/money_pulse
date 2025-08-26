// Customer create panel (SRP). Pops Customer? after save using popAfterFrame.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import '../../../domain/company/repositories/company_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import 'customer_form_utils.dart';

class CustomerCreatePanel extends ConsumerStatefulWidget {
  const CustomerCreatePanel({super.key});
  @override
  ConsumerState<CustomerCreatePanel> createState() =>
      _CustomerCreatePanelState();
}

class _CustomerCreatePanelState extends ConsumerState<CustomerCreatePanel> {
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
    if (mounted) {
      Company? def;
      try {
        def = companies.firstWhere((c) => c.isDefault == true);
      } catch (_) {
        def = companies.isNotEmpty ? companies.first : null;
      }
      _companyId ??= def?.id;
    }
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
    final entity = Customer(
      id: const Uuid().v4(),
      remoteId: null,
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
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: true,
      balance: 0,
      balanceDebt: 0,
    );

    try {
      await repo.create(entity);
      if (!mounted) return;
      await popAfterFrame<Customer?>(context, entity);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            title: const Text('Nouveau client'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(), // returns null
            ),
            actions: [
              IconButton(
                tooltip: 'Créer',
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
                          label: const Text('Créer'),
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
