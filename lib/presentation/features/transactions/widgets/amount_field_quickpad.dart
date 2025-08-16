import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

/// Champ montant avec mini-pad compact.
/// - Pas de clavier système (édition via boutons).
/// - Ligne de montants rapides (pliable) + bouton "…" pour pad complet en sheet.
/// - Toggle Ajouter/Remplacer très discret.
/// - Aperçu monnaie compact en suffixe.
/// - Verrouillage géré (lecture seule + message).
class AmountFieldQuickPad extends StatefulWidget {
  final TextEditingController controller;

  /// Montants rapides en *unités* (ex: [2000, 5000, 10000]).
  final List<int> quickUnits;

  /// Callback sur changement de texte.
  final VoidCallback? onChanged;

  /// Si true, le champ est verrouillé (lecture seule) et le pad est masqué.
  final bool lockToItems;

  /// Toggle de verrouillage (si null, l’icône lock est cachée).
  final ValueChanged<bool>? onToggleLock;

  /// Libellé du champ.
  final String labelText;

  /// Démarrer en mode **compact** (pad replié). Déplié automatiquement si false.
  final bool compact;

  /// Démarrer le pad en **déplié** même si `compact:true`.
  final bool startExpanded;

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
    bool isRequired = false,
    bool allowZero = false,
  });

  @override
  State<AmountFieldQuickPad> createState() => _AmountFieldQuickPadState();
}

class _AmountFieldQuickPadState extends State<AmountFieldQuickPad> {
  final FocusNode _nofocus = FocusNode(canRequestFocus: false);

  /// true = Ajouter ; false = Remplacer
  bool _addMode = true;

  /// Pad replié/déplié
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
    // Si on passe en lock, on replie le pad.
    if (!oldWidget.lockToItems && widget.lockToItems) {
      _expanded = false;
    }
  }

  @override
  void dispose() {
    _nofocus.dispose();
    super.dispose();
  }

  // ----------------- parsing / preview -----------------
  String _sanitize(String v) {
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

  // ----------------- actions -----------------
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

  // ----------------- UI helpers -----------------
  Widget _previewBadge() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        _preview,
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget? _buildSuffix() {
    // final buttons = <Widget>[_previewBadge()];
    final buttons = <Widget>[];

    if (widget.onToggleLock != null) {
      buttons.add(
        Tooltip(
          message: widget.lockToItems
              ? 'Verrouillé sur total articles'
              : 'Verrouiller',
          child: IconButton(
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(widget.lockToItems ? Icons.lock : Icons.lock_open),
            onPressed: () => widget.onToggleLock?.call(!widget.lockToItems),
          ),
        ),
      );
    }

    // Toggle ajouter/remplacer (compact)
    buttons.add(
      Tooltip(
        message: _addMode ? 'Ajouter' : 'Remplacer',
        child: IconButton(
          iconSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          onPressed: widget.lockToItems
              ? null
              : () => setState(() => _addMode = !_addMode),
          icon: Icon(_addMode ? Icons.add : Icons.swap_horiz),
        ),
      ),
    );

    // Effacer
    if (widget.controller.text.isNotEmpty && !widget.lockToItems) {
      buttons.add(
        Tooltip(
          message: 'Effacer',
          child: IconButton(
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
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

  ButtonStyle get _chipStyle => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    minimumSize: const Size(0, 36),
    textStyle: Theme.of(context).textTheme.bodySmall,
  );

  Widget _chip(int units) {
    final label = Formatters.amountFromCents(units * 100);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilledButton.tonal(
        onPressed: widget.lockToItems ? null : () => _tapAmount(units),
        onLongPress: widget.lockToItems ? null : () => _setUnits(units),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  void _openFullPad() {
    if (widget.lockToItems) {
      _showLockedHint();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in widget.quickUnits)
                    FilledButton.tonal(
                      style: _chipStyle,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _tapAmount(u);
                      },
                      onLongPress: () {
                        Navigator.pop(ctx);
                        _setUnits(u);
                      },
                      child: Text(
                        Formatters.amountFromCents(u * 100),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  FilledButton.tonal(
                    style: _chipStyle,
                    onPressed: () {
                      Navigator.pop(ctx);
                      final c = _toCents(widget.controller.text) / 100.0;
                      _setUnits((c * 2).round());
                    },
                    child: const Text('×2'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.controller.clear();
                      widget.onChanged?.call();
                      setState(() {});
                    },
                    child: const Text('Vider'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ----------------- build -----------------
  @override
  Widget build(BuildContext context) {
    final showRow = _expanded && !widget.lockToItems;
    // Si très compact voulu, n’afficher qu’un aperçu de 3 chips max
    final visibleUnits = widget.compact && !_expanded
        ? widget.quickUnits.take(3).toList()
        : widget.quickUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Champ (pas de clavier système)
        TextFormField(
          controller: widget.controller,
          focusNode: _nofocus,
          keyboardType: TextInputType.none, // pas de clavier
          readOnly: true,
          enableInteractiveSelection: false,
          showCursor: false,
          onTap: widget.lockToItems ? _showLockedHint : null,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge, // un poil plus compact
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: widget.labelText,
            // pas de helperText pour gagner en hauteur
            suffixIcon: _buildSuffix(),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requis';
            if (_toCents(v) <= 0) return 'Montant invalide';
            return null;
          },
        ),

        // Ligne de chips ultra-compacte + bouton "…"
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: (showRow || (widget.compact && !widget.lockToItems))
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      // Scroll horizontal compact
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final u in visibleUnits) _chip(u),
                              // Bouton "…" vers pad complet
                              if (widget.compact)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      textStyle: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    onPressed: widget.lockToItems
                                        ? null
                                        : _openFullPad,
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
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
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
