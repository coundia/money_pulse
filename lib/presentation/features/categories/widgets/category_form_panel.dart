import 'package:flutter/material.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class CategoryFormResult {
  final String code;
  final String? description;
  final String typeEntry; // 'DEBIT' | 'CREDIT'
  const CategoryFormResult({
    required this.code,
    this.description,
    required this.typeEntry,
  });
}

class CategoryFormPanel extends StatefulWidget {
  final Category? existing;
  const CategoryFormPanel({super.key, this.existing});

  @override
  State<CategoryFormPanel> createState() => _CategoryFormPanelState();
}

class _CategoryFormPanelState extends State<CategoryFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _descCtrl = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  late String _typeEntry =
      (widget.existing?.typeEntry == Category.credit ||
          widget.existing?.typeEntry == Category.debit)
      ? widget.existing!.typeEntry
      : Category.debit;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final result = CategoryFormResult(
      code: _codeCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      typeEntry: _typeEntry.toUpperCase(),
    );
    debugPrint('📤 [CategoryFormPanel] typeEntry=${result.typeEntry}');
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isEdit ? 'Modifier la catégorie' : 'Ajouter une catégorie'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code',
                hintText: 'Ex. Alimentation',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optionnel',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            const Text(
              "Type d'écriture",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Débit'),
                  selected: _typeEntry == Category.debit,
                  onSelected: (_) {
                    setState(() => _typeEntry = Category.debit);
                    debugPrint('🟢 [CategoryFormPanel] select typeEntry=DEBIT');
                  },
                ),
                ChoiceChip(
                  label: const Text('Crédit'),
                  selected: _typeEntry == Category.credit,
                  onSelected: (_) {
                    setState(() => _typeEntry = Category.credit);
                    debugPrint(
                      '🟢 [CategoryFormPanel] select typeEntry=CREDIT',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Débit = dépense, Crédit = revenu',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
