import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

import '../../app/account_selection.dart';

class TransactionQuickAddSheet extends ConsumerStatefulWidget {
  const TransactionQuickAddSheet({super.key});

  @override
  ConsumerState<TransactionQuickAddSheet> createState() =>
      _TransactionQuickAddSheetState();
}

class _TransactionQuickAddSheetState
    extends ConsumerState<TransactionQuickAddSheet> {
  final formKey = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool isDebit = true;
  String? categoryId;
  DateTime when = DateTime.now();
  List<Category> categories = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(categoryRepoProvider);
      categories = await repo.findAllActive();
      if (categories.isNotEmpty) categoryId = categories.first.id;
      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header with close button ---
              Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Ajouter une transaction',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Optional grab handle for nicer sheet UX
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              // ---------------------------------
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Expense')),
                  ButtonSegment(value: false, label: Text('Income')),
                ],
                selected: {isDebit},
                onSelectionChanged: (s) => setState(() => isDebit = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoryId,
                items: categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.code)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => categoryId = v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Category',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMd().format(when)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: when,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => when = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  // ✅ get currently selected account
                  final accountId = ref.read(selectedAccountIdProvider);
                  if (accountId == null || accountId.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select an account first')),
                    );
                    return;
                  }

                  final cents = _toCents(amountCtrl.text);

                  await ref
                      .read(quickAddTransactionUseCaseProvider)
                      .execute(
                        accountId: accountId, // ✅ pass the selected account
                        amountCents: cents,
                        isDebit: isDebit,
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        categoryId: categoryId,
                        dateTransaction: when,
                      );

                  if (mounted) Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
