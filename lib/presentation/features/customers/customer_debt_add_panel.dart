// Right drawer to add sale to customer's debt (simple amount or description).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/providers/add_sale_to_debt_usecase_provider.dart';

class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

class CustomerDebtAddPanel extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDebtAddPanel({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDebtAddPanel> createState() =>
      _CustomerDebtAddPanelState();
}

class _CustomerDebtAddPanelState extends ConsumerState<CustomerDebtAddPanel> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _when = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  int _parseAmountToCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = _parseAmountToCents(_amountCtrl.text);
    try {
      await ref
          .read(addSaleToDebtUseCaseProvider)
          .execute(
            customerId: widget.customerId,
            companyId: null,
            categoryId: null,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            when: _when,
            lines: [
              {
                'productId': null,
                'label': _descCtrl.text.trim().isEmpty
                    ? 'Vente à crédit'
                    : _descCtrl.text.trim(),
                'quantity': 1,
                'unitPrice': cents,
              },
            ],
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
      },
      child: Actions(
        actions: {
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ajouter à la dette'),
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
          body: Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      hintText: 'Ex: 25 000',
                      border: const OutlineInputBorder(),
                      helperText: _amountCtrl.text.isEmpty
                          ? null
                          : 'Aperçu: ${Formatters.amountFromCents(_parseAmountToCents(_amountCtrl.text))}',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => _parseAmountToCents(v ?? '') <= 0
                        ? 'Montant invalide'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
          ),
          bottomSheet: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Enregistrer'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
