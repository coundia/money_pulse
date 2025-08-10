import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

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
    amountCtrl.text = (e.amount / 100).toStringAsFixed(0);
    descCtrl.text = e.description ?? '';
    categoryId = e.categoryId;
    when = e.dateTransaction;
    Future.microtask(() async {
      categories = await ref.read(categoryRepoProvider).findAllActive();
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
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Description',
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final cents = _toCents(amountCtrl.text);
                  final updated = widget.entry.copyWith(
                    amount: cents,
                    typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
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
                label: const Text('Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
