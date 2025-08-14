import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

/// A money input with a quick-amount pad (chips).
/// - Shows a TextFormField to type an amount
/// - When focused (or always) shows chips 2000, 5000, 10000… that add/replace
/// - Optional lock toggle to keep amount = sum(lines)
///
/// Amounts are entered in "units" (e.g., 2000) and preview is shown using
/// Formatters.amountFromCents for consistency with the rest of the app.
class AmountFieldQuickPad extends StatefulWidget {
  final TextEditingController controller;

  /// List of quick amounts in *units* (e.g., [2000, 5000, 10000]).
  final List<int> quickUnits;

  /// Called whenever text changes.
  final VoidCallback? onChanged;

  /// If not null, shows a small lock toggle; when true, TextField is readOnly.
  final bool lockToItems;
  final ValueChanged<bool>? onToggleLock;

  /// If true, only show the quick pad when field is focused.
  final bool showQuickPadOnFocusOnly;

  /// Optional label
  final String labelText;

  const AmountFieldQuickPad({
    super.key,
    required this.controller,
    required this.quickUnits,
    this.onChanged,
    this.lockToItems = false,
    this.onToggleLock,
    this.showQuickPadOnFocusOnly = true,
    this.labelText = 'Montant',
  });

  @override
  State<AmountFieldQuickPad> createState() => _AmountFieldQuickPadState();
}

class _AmountFieldQuickPadState extends State<AmountFieldQuickPad> {
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  /// Tap mode: true = add to current, false = replace current
  bool _addMode = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ----- parsing/formatting helpers ------------------------------------------
  String _sanitize(String v) {
    // remove spaces/nbsp, normalize comma to dot; collapse multiple dots
    var s = v
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u202F\s]'), '')
        .replaceAll(',', '.');
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) {
      s = s.replaceAll('.', '');
    }
    return s;
  }

  int _toCents(String v) {
    final s = _sanitize(v);
    final d = double.tryParse(s) ?? 0;
    final c = (d * 100).round();
    return c < 0 ? 0 : c;
  }

  String get _preview =>
      Formatters.amountFromCents(_toCents(widget.controller.text));

  void _setUnits(int units) {
    widget.controller.text = units.toString();
    widget.onChanged?.call();
    setState(() {});
  }

  void _addUnits(int units) {
    final currentCents = _toCents(widget.controller.text);
    final addCents = (units * 100);
    final next = (currentCents + addCents) / 100.0;
    widget.controller.text = next.toStringAsFixed(0); // keep whole units UX
    widget.onChanged?.call();
    setState(() {});
  }

  void _onTapChip(int units) {
    if (widget.lockToItems) return;
    if (_addMode) {
      _addUnits(units);
    } else {
      _setUnits(units);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showQuickPad = widget.showQuickPadOnFocusOnly ? _hasFocus : true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                readOnly: widget.lockToItems,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\.\,\u00A0\u202F\s]'),
                  ),
                ],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: widget.labelText,
                  helperText: 'Aperçu: $_preview',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleLock != null)
                        Tooltip(
                          message: widget.lockToItems
                              ? 'Verrouillé sur total articles'
                              : 'Déverrouiller',
                          child: IconButton(
                            icon: Icon(
                              widget.lockToItems ? Icons.lock : Icons.lock_open,
                            ),
                            onPressed: () =>
                                widget.onToggleLock?.call(!widget.lockToItems),
                          ),
                        ),
                      if (widget.controller.text.isNotEmpty &&
                          !widget.lockToItems)
                        IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.controller.clear();
                            widget.onChanged?.call();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  if (_toCents(v) <= 0) return 'Montant invalide';
                  return null;
                },
                onChanged: (_) {
                  widget.onChanged?.call();
                  setState(() {});
                },
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            // Add/Replace mode switch
            Tooltip(
              message: _addMode ? 'Mode: Ajouter' : 'Mode: Remplacer',
              child: InkResponse(
                onTap: widget.lockToItems
                    ? null
                    : () => setState(() => _addMode = !_addMode),
                radius: 24,
                child: CircleAvatar(
                  radius: 18,
                  child: Icon(_addMode ? Icons.add : Icons.swap_horiz),
                ),
              ),
            ),
          ],
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showQuickPad
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...widget.quickUnits.map(
                          (u) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Tooltip(
                              message: _addMode
                                  ? 'Ajouter $u (appui long = remplacer)'
                                  : 'Remplacer par $u (appui long = idem)',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: widget.lockToItems
                                    ? null
                                    : () => _onTapChip(u),
                                onLongPress: widget.lockToItems
                                    ? null
                                    : () => _setUnits(u),
                                child: Chip(
                                  avatar: const Icon(Icons.payments, size: 18),
                                  label: Text(_formatUnits(u)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Little helpers
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: const Text('×2'),
                            onPressed: widget.lockToItems
                                ? null
                                : () {
                                    final c = _toCents(widget.controller.text);
                                    final nextUnits = ((c / 100) * 2).round();
                                    _setUnits(nextUnits);
                                  },
                          ),
                        ),
                        ActionChip(
                          label: const Text('Vider'),
                          onPressed: widget.lockToItems
                              ? null
                              : () {
                                  widget.controller.clear();
                                  widget.onChanged?.call();
                                  setState(() {});
                                },
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _formatUnits(int units) {
    // Show units as "2 000" etc. Preview already shows currency format.
    final cents = units * 100;
    final pretty = Formatters.amountFromCents(cents);
    // Remove currency symbol if your formatter includes one (optional)
    return pretty;
  }
}
