import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';

class PosCheckoutPanel extends ConsumerStatefulWidget {
  final int totalCents;
  const PosCheckoutPanel({super.key, required this.totalCents});

  @override
  ConsumerState<PosCheckoutPanel> createState() => _PosCheckoutPanelState();
}

class _PosCheckoutPanelState extends ConsumerState<PosCheckoutPanel> {
  bool isSale = true; // sale = CREDIT, purchase = DEBIT
  DateTime when = DateTime.now();
  String? categoryId;
  final descCtrl = TextEditingController();

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  String _money(int c) => (c ~/ 100).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encaissement'),
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Vente (CREDIT)')),
                  ButtonSegment(value: false, label: Text('Achat (DEBIT)')),
                ],
                selected: {isSale},
                onSelectionChanged: (s) => setState(() => isSale = s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(DateFormat.yMMMd().add_Hm().format(when)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: when,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                final t = TimeOfDay.fromDateTime(when);
                setState(
                  () =>
                      when = DateTime(d.year, d.month, d.day, t.hour, t.minute),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: ref.read(categoryRepoProvider).findAllActive(),
            builder: (context, snap) {
              final cats = snap.data ?? const [];
              return DropdownButtonFormField<String>(
                value: categoryId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Aucune catégorie'),
                  ),
                  ...cats.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.code)),
                  ),
                ],
                onChanged: (v) => setState(() => categoryId = v),
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Total ${_money(widget.totalCents)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(
                context,
                _CheckoutResult(
                  typeEntry: isSale ? 'CREDIT' : 'DEBIT',
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  categoryId: categoryId,
                  when: when,
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirmer'),
          ),
        ),
      ),
    );
  }
}

/// tiny result class mirrored here so this file is standalone for import
class _CheckoutResult {
  final String typeEntry;
  final String? description;
  final String? categoryId;
  final DateTime? when;
  const _CheckoutResult({
    required this.typeEntry,
    this.description,
    this.categoryId,
    this.when,
  });
}
