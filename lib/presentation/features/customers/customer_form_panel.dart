import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/app/providers.dart';

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
  String? _companyId;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<List<Company>> _loadCompanies() async {
    final repo = ref.read(companyRepoProvider);
    return repo.findAll(const CompanyQuery(limit: 200, offset: 0));
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le client' : 'Nouveau client'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<List<Company>>(
        future: _loadCompanies(),
        builder: (context, snap) {
          final companies = snap.data ?? const <Company>[];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _first,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _last,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _full,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet (sinon auto)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _companyId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Société',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('— Aucune —'),
                    ),
                    ...companies.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.code})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _companyId = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(isEdit ? 'Enregistrer' : 'Créer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
