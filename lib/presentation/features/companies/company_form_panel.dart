import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:jaayko/domain/company/entities/company.dart';

import '../../app/providers/company_repo_provider.dart';

class CompanyFormPanel extends ConsumerStatefulWidget {
  final Company? initial;
  const CompanyFormPanel({super.key, this.initial});

  @override
  ConsumerState<CompanyFormPanel> createState() => _CompanyFormPanelState();
}

class _CompanyFormPanelState extends ConsumerState<CompanyFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _currency = TextEditingController();
  final _taxId = TextEditingController();
  final _website = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _country = TextEditingController();
  final _postal = TextEditingController();
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _code.text = c.code;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _email.text = c.email ?? '';
      _currency.text = c.currency ?? '';
      _taxId.text = c.taxId ?? '';
      _website.text = c.website ?? '';
      _addr1.text = c.addressLine1 ?? '';
      _addr2.text = c.addressLine2 ?? '';
      _city.text = c.city ?? '';
      _region.text = c.region ?? '';
      _country.text = c.country ?? '';
      _postal.text = c.postalCode ?? '';
      _isDefault = c.isDefault;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _currency.dispose();
    _taxId.dispose();
    _website.dispose();
    _addr1.dispose();
    _addr2.dispose();
    _city.dispose();
    _region.dispose();
    _country.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(companyRepoProvider);
    final now = DateTime.now();
    final base = Company(
      id: widget.initial?.id ?? const Uuid().v4(),
      remoteId: widget.initial?.remoteId,
      code: _code.text.trim(),
      name: _name.text.trim(),
      description: null,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      website: _website.text.trim().isEmpty ? null : _website.text.trim(),
      taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
      currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
      addressLine1: _addr1.text.trim().isEmpty ? null : _addr1.text.trim(),
      addressLine2: _addr2.text.trim().isEmpty ? null : _addr2.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
      country: _country.text.trim().isEmpty ? null : _country.text.trim(),
      postalCode: _postal.text.trim().isEmpty ? null : _postal.text.trim(),
      isDefault: _isDefault,
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
        title: Text(isEdit ? 'Modifier la société' : 'Nouvelle société'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: isEdit ? 'Enregistrer' : 'Créer',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Code requis' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom',
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
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
              controller: _currency,
              decoration: const InputDecoration(
                labelText: 'Devise',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taxId,
              decoration: const InputDecoration(
                labelText: 'N° fiscal',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _website,
              decoration: const InputDecoration(
                labelText: 'Site web',
                isDense: true,
              ),
            ),
            const Divider(height: 24),
            TextFormField(
              controller: _addr1,
              decoration: const InputDecoration(
                labelText: 'Adresse (ligne 1)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addr2,
              decoration: const InputDecoration(
                labelText: 'Adresse (ligne 2)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Ville',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _region,
              decoration: const InputDecoration(
                labelText: 'Région',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(
                labelText: 'Pays',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _postal,
              decoration: const InputDecoration(
                labelText: 'Code postal',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Définir comme société par défaut'),
              dense: true,
            ),
            // ⬇️ Bouton bas supprimé (le bouton est dans l’AppBar)
          ],
        ),
      ),
    );
  }
}
