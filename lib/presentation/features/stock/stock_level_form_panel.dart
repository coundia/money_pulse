// Right drawer panel to create or edit a StockLevel with searchable pickers and ENTER submission. IDs remain stable on edit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'providers/stock_level_repo_provider.dart';
import 'package:jaayko/domain/stock/entities/stock_level.dart';

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
  final _onHandCtrl = TextEditingController(text: '0');
  final _allocatedCtrl = TextEditingController(text: '0');

  bool _loading = false;
  String? _pvId;
  String? _companyId;

  List<Map<String, Object?>> _pvOpts = const [];
  List<Map<String, Object?>> _coOpts = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(stockLevelRepoProvider);
      final pv = await repo.listProductVariants(query: '');
      final co = await repo.listCompanies(query: '');
      if (!mounted) return;
      setState(() {
        _pvOpts = pv;
        _coOpts = co;
      });
      await _loadIfNeeded();
    });
  }

  @override
  void dispose() {
    _pvCtrl.dispose();
    _companyCtrl.dispose();
    _onHandCtrl.dispose();
    _allocatedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (widget.itemId == null) return;
    final repo = ref.read(stockLevelRepoProvider);
    final item = await repo.findById(widget.itemId!);
    if (!mounted || item == null) return;
    final p = _pvOpts.firstWhere(
      (e) => (e['id']?.toString() ?? '') == item.productVariantId,
      orElse: () => {},
    );
    final c = _coOpts.firstWhere(
      (e) => (e['id']?.toString() ?? '') == item.companyId,
      orElse: () => {},
    );
    setState(() {
      _pvId = item.productVariantId;
      _companyId = item.companyId;
      _pvCtrl.text = (p['label'] as String?) ?? item.productVariantId;
      _companyCtrl.text = (c['label'] as String?) ?? item.companyId;
      _onHandCtrl.text = item.stockOnHand.toString();
      _allocatedCtrl.text = item.stockAllocated.toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pvId == null || _companyId == null) return;
    setState(() => _loading = true);
    final repo = ref.read(stockLevelRepoProvider);
    final now = DateTime.now();
    final entity = StockLevel(
      id: widget.itemId ?? const Uuid().v4(),
      productVariantId: _pvId!,
      companyId: _companyId!,
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

  String? _intv(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Valeur entière requise';
    if (n < 0) return 'Doit être ≥ 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
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
                            _AutocompleteField(
                              controller: _pvCtrl,
                              label: 'Produit',
                              hint: 'Rechercher un produit…',
                              options: _pvOpts,
                              validator: (_) =>
                                  (_pvId == null) ? 'Champ obligatoire' : null,
                              onQuery: (q) async {
                                final repo = ref.read(stockLevelRepoProvider);
                                final list = await repo.listProductVariants(
                                  query: q,
                                );
                                if (!mounted) return;
                                setState(() => _pvOpts = list);
                              },
                              onSelected: (id, label) {
                                _pvId = id;
                                _pvCtrl.text = label;
                              },
                            ),
                            const SizedBox(height: 12),
                            _AutocompleteField(
                              controller: _companyCtrl,
                              label: 'Société',
                              hint: 'Rechercher une société…',
                              options: _coOpts,
                              validator: (_) => (_companyId == null)
                                  ? 'Champ obligatoire'
                                  : null,
                              onQuery: (q) async {
                                final repo = ref.read(stockLevelRepoProvider);
                                final list = await repo.listCompanies(query: q);
                                if (!mounted) return;
                                setState(() => _coOpts = list);
                              },
                              onSelected: (id, label) {
                                _companyId = id;
                                _companyCtrl.text = label;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _onHandCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                            const Center(
                              child: Text('Appuyez sur Entrée pour valider'),
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

class _AutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<Map<String, Object?>> options;
  final String? Function(String?)? validator;
  final Future<void> Function(String) onQuery;
  final void Function(String id, String label) onSelected;

  const _AutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.options,
    required this.validator,
    required this.onQuery,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, Object?>>(
      optionsBuilder: (text) {
        final q = text.text.toLowerCase().trim();
        if (q.isEmpty) return options;
        return options.where(
          (e) => ((e['label'] as String?) ?? '').toLowerCase().contains(q),
        );
      },
      displayStringForOption: (e) => (e['label'] as String?) ?? '',
      fieldViewBuilder: (ctx, textCtrl, focus, onSubmit) {
        if (controller.text.isNotEmpty && textCtrl.text.isEmpty) {
          textCtrl.text = controller.text;
        }
        return TextFormField(
          controller: textCtrl,
          focusNode: focus,
          validator: validator,
          onChanged: (v) => onQuery(v),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: label,
            hintText: hint,
            suffixIcon: textCtrl.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      textCtrl.clear();
                      controller.clear();
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelect, opts) {
        final list = opts.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = list[i];
                  final label = (e['label'] as String?) ?? '';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.list_alt),
                    title: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      final id = (e['id']?.toString() ?? '');
                      onSelected(id, label);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (e) {
        final id = (e['id']?.toString() ?? '');
        final label = (e['label'] as String?) ?? '';
        controller.text = label;
        onSelected(id, label);
      },
    );
  }
}
