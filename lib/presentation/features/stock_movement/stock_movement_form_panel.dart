// Right drawer form for stock movement with stable ID on edit and Enter submission.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'providers/stock_movement_repo_provider.dart';
import '../../../domain/stock/entities/stock_movement.dart';

class StockMovementFormPanel extends ConsumerStatefulWidget {
  final String? itemId;
  const StockMovementFormPanel({super.key, this.itemId});

  @override
  ConsumerState<StockMovementFormPanel> createState() =>
      _StockMovementFormPanelState();
}

class _StockMovementFormPanelState
    extends ConsumerState<StockMovementFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _productCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '0');
  String _type = 'IN';
  String? _productId;
  String? _companyId;

  List<Map<String, Object?>> _pvOpts = const [];
  List<Map<String, Object?>> _coOpts = const [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(stockMovementRepoProvider);
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
    _productCtrl.dispose();
    _companyCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (widget.itemId == null) return;
    final repo = ref.read(stockMovementRepoProvider);
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
      _type = item.type;
      _productId = item.productVariantId;
      _companyId = item.companyId;
      _productCtrl.text = (p['label'] as String?) ?? item.productVariantId;
      _companyCtrl.text = (c['label'] as String?) ?? item.companyId;
      _qtyCtrl.text = item.quantity.toString();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null || _companyId == null) return;
    setState(() => _loading = true);
    final repo = ref.read(stockMovementRepoProvider);
    final now = DateTime.now();
    final entity = StockMovement(
      id: widget.itemId ?? const Uuid().v4(),
      type: _type,
      quantity: int.parse(_qtyCtrl.text.trim()),
      companyId: _companyId!,
      productVariantId: _productId!,
      orderLineId: null,
      discriminator: 'MANUAL',
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
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.itemId == null
                  ? 'Nouveau mouvement'
                  : 'Modifier le mouvement',
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
                          DropdownButtonFormField<String>(
                            value: _type,
                            items: const [
                              DropdownMenuItem(
                                value: 'IN',
                                child: Text('Entrée (IN)'),
                              ),
                              DropdownMenuItem(
                                value: 'OUT',
                                child: Text('Sortie (OUT)'),
                              ),
                              DropdownMenuItem(
                                value: 'ALLOCATE',
                                child: Text('Allouer (ALLOCATE)'),
                              ),
                              DropdownMenuItem(
                                value: 'RELEASE',
                                child: Text('Libérer (RELEASE)'),
                              ),
                              DropdownMenuItem(
                                value: 'ADJUST',
                                child: Text('Ajuster (ADJUST)'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _type = v ?? 'IN'),
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AutocompleteField(
                            controller: _productCtrl,
                            label: 'Produit',
                            hint: 'Rechercher un produit…',
                            options: _pvOpts,
                            validator: (_) => (_productId == null)
                                ? 'Champ obligatoire'
                                : null,
                            onQuery: (q) async {
                              final repo = ref.read(stockMovementRepoProvider);
                              final list = await repo.listProductVariants(
                                query: q,
                              );
                              if (!mounted) return;
                              setState(() => _pvOpts = list);
                            },
                            onSelected: (id, label) {
                              _productId = id;
                              _productCtrl.text = label;
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
                              final repo = ref.read(stockMovementRepoProvider);
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
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(),
                            ),
                            validator: _intv,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
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
