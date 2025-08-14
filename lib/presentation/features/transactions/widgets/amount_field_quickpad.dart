import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

/// A money input with a quick-amount pad (chips).
///
/// - TextFormField to type an amount
/// - Horizontal quick chips (e.g., 2000, 5000, 10000…) to add/replace
/// - Optional lock toggle to keep amount = sum(lines) (readOnly when locked)
/// - Shows a live currency preview using Formatters.amountFromCents
///
/// Amounts in `quickUnits` are *units* (e.g., 2000), not cents.
/// The field text is also in units; preview shows formatted currency.
class AmountFieldQuickPad extends StatefulWidget {
  final TextEditingController controller;

  /// Quick amounts in *units* (e.g., [2000, 5000, 10000]).
  final List<int> quickUnits;

  /// Called whenever the text changes.
  final VoidCallback? onChanged;

  /// When true, the field is readOnly and shows a lock icon.
  final bool lockToItems;

  /// Toggle for the lock state. If null, the lock icon is hidden.
  final ValueChanged<bool>? onToggleLock;

  /// If true, only show the quick pad when the field has focus.
  final bool showQuickPadOnFocusOnly;

  /// Field label.
  final String labelText;

  /// Request focus automatically when the widget appears (if not locked).
  final bool autofocus;

  const AmountFieldQuickPad({
    super.key,
    required this.controller,
    required this.quickUnits,
    this.onChanged,
    this.lockToItems = false,
    this.onToggleLock,
    this.showQuickPadOnFocusOnly = true,
    this.labelText = 'Montant',
    this.autofocus = true,
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
    _focusNode.canRequestFocus =
        !widget.lockToItems; // bloque la prise de focus si verrouillé
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _hasFocus = _focusNode.hasFocus);
    });

    // Ensure focus after first frame (more reliable in sheets/drawers)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autofocus && !widget.lockToItems) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AmountFieldQuickPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lockToItems != widget.lockToItems) {
      // Met à jour la capacité à prendre le focus
      _focusNode.canRequestFocus = !widget.lockToItems;

      if (widget.lockToItems) {
        // Si on vient de verrouiller alors que le champ avait le focus, on le retire
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      } else {
        // Si on déverrouille et que l'autofocus est souhaité, on peut redemander le focus
        if (widget.autofocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _focusNode.requestFocus();
          });
        }
      }
      // Forcer le rebuild pour que le quick pad suive l'état
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ----- parsing/formatting helpers ------------------------------------------
  String _sanitize(String v) {
    // Remove spaces (incl. NBSP), normalize comma to dot; collapse multiple dots
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
    final nextUnits = ((currentCents + addCents) / 100.0).round();
    widget.controller.text = nextUnits.toString();
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

  void _showLockedHint() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Montant verrouillé sur le total des articles'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Masque le quick pad lorsqu'on est verrouillé,
    // et sinon on suit la règle "showQuickPadOnFocusOnly".
    final showQuickPad =
        !widget.lockToItems &&
        (widget.showQuickPadOnFocusOnly ? _hasFocus : true);

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
                enableInteractiveSelection: !widget.lockToItems,
                autofocus: false, // focus handled in initState/didUpdateWidget
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\.\,\u00A0\u202F\s]'),
                  ),
                ],
                onTap: widget.lockToItems
                    ? () {
                        // Empêche toute interaction lorsqu'il est verrouillé
                        _focusNode.unfocus();
                        _showLockedHint();
                      }
                    : null,
                onTapOutside: (_) {
                  if (_focusNode.hasFocus) _focusNode.unfocus();
                },
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

        // Quick pad (chips)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showQuickPad
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Main quick chips with long press to "replace"
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

                        // Helpers
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: const Text('×2'),
                            onPressed: widget.lockToItems
                                ? null
                                : () {
                                    final c = _toCents(widget.controller.text);
                                    final nextUnits = ((c / 100.0) * 2).round();
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
    // Render chips with your standard formatter (e.g., "2 000 XOF").
    // Preview already shows currency; keeping full format helps consistency.
    final cents = units * 100;
    return Formatters.amountFromCents(cents);
  }
}
