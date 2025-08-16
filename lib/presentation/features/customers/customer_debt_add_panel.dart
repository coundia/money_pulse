// Right drawer to add an amount to a customer's open debt using AmountFieldQuickPad with refresh.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/amount_utils.dart';
import 'package:money_pulse/presentation/features/transactions/widgets/amount_field_quickpad.dart';
import 'package:money_pulse/presentation/app/providers/checkout_cart_usecase_provider.dart'
    hide checkoutCartUseCaseProvider;
import '../../app/providers.dart';
import 'providers/customer_linked_providers.dart';
import 'providers/customer_detail_providers.dart';
import 'providers/customer_list_providers.dart';

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
  final _descCtrl = TextEditingController(text: 'Ajout à dette');
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final amountCents = _amountCtrl.toCents();
    if (amountCents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Montant invalide')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final usecase = ref.read(checkoutCartUseCaseProvider);
      await usecase.execute(
        typeEntry: 'DEBT',
        accountId: null,
        companyId: null,
        customerId: widget.customerId,
        categoryId: null,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        when: DateTime.now(),
        lines: [
          {
            'productId': null,
            'label': 'Ajout à dette',
            'quantity': 1,
            'unitPrice': amountCents,
          },
        ],
      );

      ref.invalidate(openDebtByCustomerProvider(widget.customerId));
      ref.invalidate(customerByIdProvider(widget.customerId));
      ref.invalidate(customerListProvider);
      ref.invalidate(customerCountProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
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
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AmountFieldQuickPad(
                  controller: _amountCtrl,
                  quickUnits: const [
                    1000,
                    2000,
                    5000,
                    10000,
                    20000,
                    50000,
                    100000,
                  ],
                  labelText: 'Montant (CFA)',
                  compact: true,
                  startExpanded: true,
                  isRequired: true,
                  allowZero: false,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 20),
                SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_submitting ? 'Traitement...' : 'Valider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
