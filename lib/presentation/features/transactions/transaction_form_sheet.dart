import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionEntry entry;
  const TransactionFormSheet({super.key, required this.entry});

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
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
    final e = widget.entry;
    isDebit = e.typeEntry == 'DEBIT';
    amountCtrl.text = (e.amount / 100).toStringAsFixed(2);
    descCtrl.text = e.description ?? '';
    categoryId = e.categoryId;
    when = e.dateTransaction;
    Future.microtask(() async {
      final repo = ref.read(categoryRepoProvider);
      final cats = await repo.findAllActive();
      if (!mounted) return;
      setState(() => categories = cats);
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
    final typeLabel = isDebit ? 'Expense' : 'Income';
    final typeColor = isDebit
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isDebit
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    color: typeColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Transaction',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),

              // Type indicator (read-only)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: typeColor,
                ),
                title: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('Transaction type'),
              ),
              const Divider(height: 24),

              // Amount
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
                  prefixText: '',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                value: categoryId,
                items: categories
                    .where(
                      (c) => c.typeEntry == widget.entry.typeEntry,
                    ) // Filter to match entry type
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.code}${c.description != null ? ' — ${c.description}' : ''}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => categoryId = v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Category',
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
              ),
              const SizedBox(height: 12),

              // Date
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
              const SizedBox(height: 20),

              // Update button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final cents = _toCents(amountCtrl.text);
                    final updated = widget.entry.copyWith(
                      amount: cents,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      categoryId: categoryId,
                      dateTransaction: when,
                    );
                    await ref.read(transactionRepoProvider).update(updated);
                    if (mounted) Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Update Transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
