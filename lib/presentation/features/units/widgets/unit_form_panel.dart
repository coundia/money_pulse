import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/units/entities/unit.dart';

class UnitFormResult {
  final String id;
  final String code;
  final String? name;
  final String? description;

  const UnitFormResult({
    required this.id,
    required this.code,
    this.name,
    this.description,
  });
}

class UnitFormPanel extends StatefulWidget {
  final Unit? existing;
  const UnitFormPanel({super.key, this.existing});

  @override
  State<UnitFormPanel> createState() => _UnitFormPanelState();
}

class _UnitFormPanelState extends State<UnitFormPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Modifier l’unité' : 'Nouvelle unité'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final id = widget.existing?.id ?? const Uuid().v4();
              Navigator.pop(
                context,
                UnitFormResult(
                  id: id,
                  code: _code.text.trim(),
                  name: _name.text.trim().isEmpty ? null : _name.text.trim(),
                  description: _desc.text.trim().isEmpty
                      ? null
                      : _desc.text.trim(),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code (ex: kg, L, pc)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
