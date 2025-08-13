import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../../../domain/company/repositories/company_repository.dart';
import '../../../domain/customer/repositories/customer_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionEntry entry;
  const TransactionFormSheet({super.key, required this.entry});

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final formKey = GlobalKey<FormState>();

  // fields
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isDebit = true;
  String? categoryId;
  DateTime when = DateTime.now();

  // party fields
  String? companyId;
  String? customerId;
  List<Company> companies = const [];
  List<Customer> customers = const [];

  // data
  List<Category> categories = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    isDebit = e.typeEntry == 'DEBIT';
    amountCtrl.text = (e.amount / 100).toStringAsFixed(2);
    descCtrl.text = e.description ?? '';
    categoryId = e.categoryId;
    when = e.dateTransaction;
    companyId = e.companyId;
    customerId = e.customerId;

    // load lists async
    Future.microtask(() async {
      final catRepo = ref.read(categoryRepoProvider);
      final coRepo = ref.read(companyRepoProvider);
      final cuRepo = ref.read(customerRepoProvider);

      final cats = await catRepo.findAllActive();
      final cos = await coRepo.findAll(
        const CompanyQuery(limit: 300, offset: 0),
      );
      // customers optionally filtered by company
      final cus = await cuRepo.findAll(
        CustomerQuery(
          companyId: (companyId ?? '').isEmpty ? null : companyId,
          limit: 300,
          offset: 0,
        ),
      );

      if (!mounted) return;
      setState(() {
        categories = cats;
        companies = cos;
        customers = cus;
      });
    });
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  int _toCents(String v) {
    final s = v.replaceAll(',', '.').replaceAll(' ', '');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  String get _amountPreview =>
      Formatters.amountFromCents(_toCents(amountCtrl.text));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      // keep current time of day
      setState(
        () => when = DateTime(
          picked.year,
          picked.month,
          picked.day,
          when.hour,
          when.minute,
          when.second,
          when.millisecond,
          when.microsecond,
        ),
      );
    }
  }

  Future<void> _onSelectCompany(String? id) async {
    setState(() {
      companyId = id;
      customerId = null; // reset customer when company changes
      customers = const [];
    });
    final cuRepo = ref.read(customerRepoProvider);
    final list = await cuRepo.findAll(
      CustomerQuery(
        companyId: (id ?? '').isEmpty ? null : id,
        limit: 300,
        offset: 0,
      ),
    );
    if (!mounted) return;
    setState(() => customers = list);
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final cents = _toCents(amountCtrl.text);
    final updated = widget.entry.copyWith(
      amount: cents,
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      categoryId: categoryId,
      dateTransaction: when,
      companyId: companyId,
      customerId: customerId,
      updatedAt: DateTime.now(),
      isDirty: true,
      version: widget.entry.version + 1,
    );
    await ref.read(transactionRepoProvider).update(updated);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = isDebit ? 'Dépense' : 'Revenu';
    final accent = isDebit
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la transaction'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type (readonly)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                color: accent,
              ),
              title: Text(
                typeLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Type de transaction'),
            ),
            const Divider(height: 24),

            // Montant
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Montant',
                helperText: 'Saisissez le montant en unités (ex: 1500.00)',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Aperçu: ${_amountPreview}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),

            // Catégorie
            DropdownButtonFormField<String>(
              value: categoryId,
              items: categories
                  .where((c) => c.typeEntry == widget.entry.typeEntry)
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.code}${(c.description ?? '').isNotEmpty ? ' — ${c.description}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => categoryId = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Catégorie',
              ),
            ),
            const SizedBox(height: 12),

            // Tiers (Société & Client)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tiers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: companyId,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Aucune société —'),
                        ),
                        ...companies.map(
                          (co) => DropdownMenuItem(
                            value: co.id,
                            child: Text(
                              '${co.name} (${co.code})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => _onSelectCompany(v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Société',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: customerId,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Aucun client —'),
                        ),
                        ...customers.map(
                          (cu) => DropdownMenuItem(
                            value: cu.id,
                            child: Text(
                              cu.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => customerId = v),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Client',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: descCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Description',
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(Formatters.dateFull(when)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
