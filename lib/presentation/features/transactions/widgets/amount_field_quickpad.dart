// Amount field with quick chips and a responsive bottom-sheet keypad. Supports +, -, × operations and CC (clear all). French UI, system keyboard hidden.

import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AmountFieldQuickPad extends StatefulWidget {
  final TextEditingController controller;
  final List<int> quickUnits;
  final VoidCallback? onChanged;
  final bool lockToItems;
  final ValueChanged<bool>? onToggleLock;
  final String labelText;
  final bool compact;
  final bool startExpanded;
  final bool isRequired;
  final bool allowZero;

  const AmountFieldQuickPad({
    super.key,
    required this.controller,
    required this.quickUnits,
    this.onChanged,
    this.lockToItems = false,
    this.onToggleLock,
    this.labelText = 'Montant',
    this.compact = true,
    this.startExpanded = false,
    this.isRequired = false,
    this.allowZero = false,
  });

  @override
  State<AmountFieldQuickPad> createState() => _AmountFieldQuickPadState();
}

class _AmountFieldQuickPadState extends State<AmountFieldQuickPad> {
  final FocusNode _nofocus = FocusNode(canRequestFocus: false);
  bool _addMode = true;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        !widget.compact || (widget.startExpanded && !widget.lockToItems);
  }

  @override
  void didUpdateWidget(covariant AmountFieldQuickPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.lockToItems && widget.lockToItems) {
      _expanded = false;
    }
  }

  @override
  void dispose() {
    _nofocus.dispose();
    super.dispose();
  }

  String _sanitize(String v) {
    var s = v
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u202F\s]'), '')
        .replaceAll(',', '.');
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) s = s.replaceAll('.', '');
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

  void _tapAmount(int units) {
    if (widget.lockToItems) return;
    _addMode ? _addUnits(units) : _setUnits(units);
  }

  void _showLockedHint() {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      const SnackBar(
        content: Text('Montant verrouillé sur le total des articles'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  ButtonStyle get _chipStyle => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    minimumSize: const Size(0, 32),
    visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
    textStyle: Theme.of(context).textTheme.bodySmall,
  );

  Widget _chip(int units) {
    final label = Formatters.amountFromCents(units * 100);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilledButton.tonal(
        style: _chipStyle,
        onPressed: widget.lockToItems ? null : () => _tapAmount(units),
        onLongPress: widget.lockToItems ? null : () => _setUnits(units),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget? _buildSuffix() {
    final buttons = <Widget>[];
    if (widget.onToggleLock != null) {
      buttons.add(
        Tooltip(
          message: widget.lockToItems
              ? 'Verrouillé sur total articles'
              : 'Verrouiller',
          child: IconButton(
            iconSize: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: Icon(widget.lockToItems ? Icons.lock : Icons.lock_open),
            onPressed: () => widget.onToggleLock?.call(!widget.lockToItems),
          ),
        ),
      );
    }
    buttons.add(
      Tooltip(
        message: _addMode ? 'Ajouter' : 'Remplacer',
        child: IconButton(
          iconSize: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: widget.lockToItems
              ? null
              : () => setState(() => _addMode = !_addMode),
          icon: Icon(_addMode ? Icons.add : Icons.swap_horiz),
        ),
      ),
    );
    buttons.add(
      Tooltip(
        message: 'Clavier',
        child: IconButton(
          iconSize: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: widget.lockToItems ? null : _openKeypadSheet,
          icon: const Icon(Icons.keyboard),
        ),
      ),
    );
    if (widget.controller.text.isNotEmpty && !widget.lockToItems) {
      buttons.add(
        Tooltip(
          message: 'Effacer',
          child: IconButton(
            iconSize: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () {
              widget.controller.clear();
              widget.onChanged?.call();
              setState(() {});
            },
            icon: const Icon(Icons.clear),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  Future<void> _openKeypadSheet() async {
    if (widget.lockToItems) {
      _showLockedHint();
      return;
    }

    String temp = _sanitize(widget.controller.text);
    bool addMode = _addMode;
    int? leftCents;
    String? op;

    int _mulCents(int a, int b) => ((a * b) / 100).round();

    int _evalPending({
      required int? left,
      required String? operator,
      required int? right,
    }) {
      if (operator == null || left == null) return right ?? 0;
      final r = right ?? 0;
      if (operator == '+') return left + r;
      if (operator == '-') return left - r;
      if (operator == '×') return _mulCents(left, r);
      return r;
    }

    String _appendZeros(String value, String zeros) {
      if (value.isEmpty) return '0$zeros';
      if (value.contains('.')) {
        final parts = value.split('.');
        final frac = parts.length > 1 ? parts[1] : '';
        if (frac.length >= 2) return value;
        final need = (frac.length + zeros.length) > 2
            ? (2 - frac.length)
            : zeros.length;
        return '${parts[0]}.${frac + zeros.substring(0, need)}';
      } else {
        return '$value$zeros';
      }
    }

    void _pressOperator(
      String symbol,
      void Function(VoidCallback fn) localSet,
    ) {
      final current = temp.isEmpty ? null : _toCents(temp);
      if (leftCents == null && current != null) {
        leftCents = current;
        op = symbol;
        temp = '';
      } else if (leftCents != null && current == null) {
        op = symbol;
      } else if (leftCents != null && current != null) {
        leftCents = _evalPending(left: leftCents, operator: op, right: current);
        op = symbol;
        temp = '';
      }
      localSet(() {});
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String formattedCents(int cents) => Formatters.amountFromCents(cents);
        String formattedStr(String s) =>
            Formatters.amountFromCents(_toCents(s));

        void applyAndClose() {
          final pending = temp.isEmpty ? null : _toCents(temp);
          final resultCents = _evalPending(
            left: leftCents,
            operator: op,
            right: pending,
          );
          final baseCents = _toCents(widget.controller.text);
          final finalCents = addMode ? (baseCents + resultCents) : resultCents;
          final units = (finalCents / 100.0).toStringAsFixed(2);
          final normalized = units.endsWith('.00')
              ? units.substring(0, units.length - 3)
              : units
                    .replaceAll(RegExp(r'0$'), '')
                    .replaceAll(RegExp(r'\.$'), '');
          widget.controller.text = normalized.isEmpty ? '0' : normalized;
          widget.onChanged?.call();
          Navigator.pop(ctx);
          setState(() {});
        }

        return StatefulBuilder(
          builder: (ctx, localSet) {
            final chipStyle = FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              textStyle: Theme.of(context).textTheme.bodySmall,
            );

            final chips = <Widget>[
              if (widget.allowZero)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: const VisualDensity(
                      horizontal: -3,
                      vertical: -3,
                    ),
                    textStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                  onPressed: () {
                    temp = '0';
                    localSet(() {});
                  },
                  child: const Text('0'),
                ),
              for (final u in widget.quickUnits)
                FilledButton.tonal(
                  style: chipStyle,
                  onPressed: () {
                    final addTo = temp.isEmpty ? 0 : _toCents(temp);
                    final next = addMode ? (addTo + u * 100) : (u * 100);
                    temp = (next / 100.0).toStringAsFixed(2);
                    if (temp.endsWith('.00'))
                      temp = temp.substring(0, temp.length - 3);
                    localSet(() {});
                  },
                  onLongPress: () {
                    temp = u.toString();
                    localSet(() {});
                  },
                  child: Text(
                    Formatters.amountFromCents(u * 100),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              FilledButton.tonal(
                style: chipStyle,
                onPressed: () {
                  final t = (_toCents(temp.isEmpty ? '1' : temp) * 2) / 100.0;
                  temp = t.toStringAsFixed(2);
                  if (temp.endsWith('.00'))
                    temp = temp.substring(0, temp.length - 3);
                  localSet(() {});
                },
                child: const Text('×2'),
              ),
            ];

            ButtonStyle keyStyleFilled = FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              textStyle: Theme.of(context).textTheme.titleSmall,
            );
            ButtonStyle keyStyleOutlined = OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              textStyle: Theme.of(context).textTheme.titleSmall,
            );
            ButtonStyle keyStyleOperator = FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              textStyle: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            );
            ButtonStyle keyStyleDanger = OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              foregroundColor: Theme.of(context).colorScheme.error,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              textStyle: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            );

            Widget keyButton(
              String label,
              VoidCallback onTap, {
              String kind = 'num',
            }) {
              final child = Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
              if (kind == 'op') {
                return FilledButton(
                  onPressed: onTap,
                  style: keyStyleOperator,
                  child: child,
                );
              } else if (kind == 'del') {
                return OutlinedButton(
                  onPressed: onTap,
                  style: keyStyleOutlined,
                  child: child,
                );
              } else if (kind == 'danger') {
                return OutlinedButton(
                  onPressed: onTap,
                  style: keyStyleDanger,
                  child: child,
                );
              }
              return FilledButton.tonal(
                onPressed: onTap,
                style: keyStyleFilled,
                child: child,
              );
            }

            void tapKey(String k) {
              if (k == '⌫') {
                if (temp.isNotEmpty) temp = temp.substring(0, temp.length - 1);
              } else if (k == ',' || k == '.') {
                if (!temp.contains('.')) temp = temp.isEmpty ? '0.' : '$temp.';
              } else if (k == '00' || k == '000') {
                temp = _appendZeros(temp, k);
              } else if (k == 'CC') {
                temp = '';
                leftCents = null;
                op = null;
              } else if (k == '+' || k == '-' || k == '×') {
                _pressOperator(k, localSet);
              } else {
                if (k == '0' && temp == '0') {
                } else {
                  temp = temp == '0' ? k : '$temp$k';
                }
              }
              localSet(() {});
            }

            List<String> labels = [
              '1',
              '2',
              '3',

              '4',
              '5',
              '6',

              '7',
              '8',
              '9',
              '0',
              '00',
              '000',
              ',',
              '×',
              '-',
              '+',
              'CC',
              '⌫',
            ];

            List<Widget> keys = labels.map((l) {
              if (l == '+' || l == '-' || l == '×') {
                return keyButton(l, () => tapKey(l), kind: 'op');
              } else if (l == '⌫') {
                return keyButton(l, () => tapKey(l), kind: 'del');
              } else if (l == 'CC') {
                return keyButton(l, () => tapKey(l), kind: 'danger');
              } else {
                return keyButton(l, () => tapKey(l));
              }
            }).toList();

            return LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth;
                final cols = w < 360 ? 3 : (w < 520 ? 4 : 5);
                final spacing = 8.0;
                final tileW = (w - spacing * (cols - 1)) / cols;
                final desiredH = w >= 600 ? 48.0 : 42.0;
                final aspect = tileW / desiredH;

                final exprLeft = leftCents == null
                    ? null
                    : formattedCents(leftCents!);
                final exprMid = op ?? '';
                final exprRight = temp.isEmpty ? '' : formattedStr(temp);
                final hasExpr = exprLeft != null || exprRight.isNotEmpty;

                final previewResult = hasExpr
                    ? formattedCents(
                        _evalPending(
                          left: leftCents,
                          operator: op,
                          right: temp.isEmpty ? null : _toCents(temp),
                        ),
                      )
                    : (temp.isEmpty ? '—' : formattedStr(temp));

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    top: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Clavier montant',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('Ajouter'),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('Remplacer'),
                              ),
                            ],
                            selected: {addMode},
                            onSelectionChanged: (s) =>
                                localSet(() => addMode = s.first),
                            showSelectedIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hasExpr)
                        Text(
                          '${exprLeft ?? ''} ${exprMid.isEmpty ? '' : exprMid} ${exprRight.isEmpty ? '' : exprRight}'
                              .trim(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        previewResult,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...chips.map(
                              (w) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: w,
                              ),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: -3,
                                  vertical: -3,
                                ),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.bodySmall,
                              ),
                              onPressed: () {
                                temp = '';
                                leftCents = null;
                                op = null;
                                localSet(() {});
                              },
                              child: const Text('Vider'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: cols,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: aspect,
                        children: keys,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: applyAndClose,
                              icon: const Icon(Icons.check),
                              label: const Text('Valider'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                              label: const Text('Annuler'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showRow = _expanded && !widget.lockToItems;
    final visibleUnits = widget.compact && !_expanded
        ? widget.quickUnits.take(3).toList()
        : widget.quickUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _nofocus,
          keyboardType: TextInputType.none,
          readOnly: true,
          enableInteractiveSelection: false,
          showCursor: false,
          onTap: widget.lockToItems ? _showLockedHint : _openKeypadSheet,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: widget.labelText,
            suffixIcon: _buildSuffix(),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            helperText: _preview.isEmpty ? null : _preview,
            helperMaxLines: 1,
          ),
          validator: (v) {
            final txt = v?.trim() ?? '';
            if (txt.isEmpty) return widget.isRequired ? 'Requis' : null;
            final cents = _toCents(txt);
            if (cents < 0) return 'Montant invalide';
            if (!widget.allowZero && cents == 0) return 'Montant invalide';
            return null;
          },
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: (showRow || (widget.compact && !widget.lockToItems))
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (!widget.compact && widget.allowZero)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      visualDensity: const VisualDensity(
                                        horizontal: -3,
                                        vertical: -3,
                                      ),
                                      textStyle: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    onPressed: widget.lockToItems
                                        ? null
                                        : () => _setUnits(0),
                                    child: const Text('0'),
                                  ),
                                ),
                              for (final u in visibleUnits) _chip(u),
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    visualDensity: const VisualDensity(
                                      horizontal: -3,
                                      vertical: -3,
                                    ),
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  onPressed: widget.lockToItems
                                      ? null
                                      : _openKeypadSheet,
                                  child: const Text('…'),
                                ),
                              ),
                              if (!widget.compact) ...[
                                FilledButton.tonal(
                                  style: _chipStyle,
                                  onPressed: widget.lockToItems
                                      ? null
                                      : () {
                                          final c =
                                              _toCents(widget.controller.text) /
                                              100.0;
                                          _setUnits((c * 2).round());
                                        },
                                  child: const Text('×2'),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    visualDensity: const VisualDensity(
                                      horizontal: -3,
                                      vertical: -3,
                                    ),
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  onPressed: widget.lockToItems
                                      ? null
                                      : () {
                                          widget.controller.clear();
                                          widget.onChanged?.call();
                                          setState(() {});
                                        },
                                  child: const Text('Vider'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
