// Right drawer panel to create or edit a StockLevel, with ENTER to submit

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'providers/stock_level_repo_provider.dart';
import 'package:money_pulse/domain/stock/entities/stock_level.dart';

class StockLevelFormPanel extends ConsumerStatefulWidget {
  final String? itemId;
  const StockLevelFormPanel({super.key, this.itemId});

  @override
  ConsumerState<StockLevelFormPanel> createState() =>
      _StockLevelFormPanelState();
}

class _StockLevelFormPanelState extends ConsumerState<StockLevelFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _pvCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _onHandCtrl = TextEditingController();
  final _allocatedCtrl = TextEditingController();
  bool _loading = false;
  int? _pvId;

  @override
  void initState() {
    super.initState();
    _allocatedCtrl.text = '0';
    _onHandCtrl.text = '0';
    Future.microtask(_loadIfNeeded);
  }

  Future<void> _loadIfNeeded() async {
    if (widget.itemId == null) return;
    final repo = ref.read(stockLevelRepoProvider);
    final item = await repo.findById(widget.itemId!);
    if (!mounted || item == null) return;
    setState(() {
      _pvId = item.productVariantId;
      _pvCtrl.text = item.productVariantId.toString();
      _companyCtrl.text = item.companyId;
      _onHandCtrl.text = item.stockOnHand.toString();
      _allocatedCtrl.text = item.stockAllocated.toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(stockLevelRepoProvider);
    final now = DateTime.now();
    final entity = StockLevel(
      id: widget.itemId != null ? int.parse(widget.itemId!) : null,
      productVariantId: int.parse(_pvCtrl.text.trim()),
      companyId: _companyCtrl.text.trim(),
      stockOnHand: int.parse(_onHandCtrl.text.trim()),
      stockAllocated: int.parse(_allocatedCtrl.text.trim()),
      createdAt: now,
      updatedAt: now,
    );
    try {
      if (widget.itemId == null) {
        await repo.create(entity);
      } else {
        await repo.update(entity);
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;
  String? _intv(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Valeur entière requise';
    if (n < 0) return 'Doit être ≥ 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shortcuts(
      shortcuts: {},
      child: Actions(
        actions: <Type, Action<Intent>>{
          Intent: CallbackAction<Intent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.itemId == null
                    ? 'Nouveau niveau de stock'
                    : 'Modifier le stock',
              ),
            ),
            body: SafeArea(
              child: AbsorbPointer(
                absorbing: _loading,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          children: [
                            TextFormField(
                              controller: _pvCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'ID produit (variant)',
                                hintText: 'Entrez l’ID du variant produit',
                                border: OutlineInputBorder(),
                              ),
                              validator: _intv,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _companyCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'ID entreprise',
                                hintText: 'Entrez l’ID de l’entreprise',
                                border: OutlineInputBorder(),
                              ),
                              validator: _req,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _onHandCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Stock disponible',
                                hintText: 'Quantité en stock',
                                border: OutlineInputBorder(),
                              ),
                              validator: _intv,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _allocatedCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Stock alloué',
                                hintText: 'Quantité réservée',
                                border: OutlineInputBorder(),
                              ),
                              validator: _intv,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _submit,
                                    icon: const Icon(Icons.check),
                                    label: Text(
                                      _loading
                                          ? 'Enregistrement…'
                                          : 'Enregistrer',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.of(
                                            context,
                                          ).maybePop(false),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Annuler'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Appuyez sur Entrée pour valider',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
