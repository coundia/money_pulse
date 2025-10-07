// marketplace/presentation/widgets/companies_chips_row.dart
// Displays avatar-only horizontal companies filter row. The first "ALL" clears selection, triggers a true reload via parent's onRefreshAll, and logs user actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/marketplace_company_provider.dart';

class CompaniesChipsRow extends ConsumerStatefulWidget {
  final String baseUri;
  final String? selectedId;
  final void Function(String? id) onSelect;
  final VoidCallback onRefreshAll;

  const CompaniesChipsRow({
    super.key,
    required this.baseUri,
    required this.selectedId,
    required this.onSelect,
    required this.onRefreshAll,
  });

  @override
  ConsumerState<CompaniesChipsRow> createState() => _CompaniesChipsRowState();
}

class _CompaniesChipsRowState extends ConsumerState<CompaniesChipsRow> {
  final _scrollCtrl = ScrollController();
  String? _overrideSelectedId;

  @override
  void didUpdateWidget(covariant CompaniesChipsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _overrideSelectedId = null;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String? get _effectiveSelectedId => _overrideSelectedId ?? widget.selectedId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketplaceCompaniesProvider(widget.baseUri));

    return SizedBox(
      height: 70,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: async.when(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();

            final items = <Widget>[
              _avatarButton(
                context: context,
                tooltip: 'Tous les produits',
                selected: _effectiveSelectedId == null,
                showActiveBadge: false,
                onTap: () {
                  debugPrint(
                    '[CompaniesChipsRow] ALL tapped -> clear selection and reload',
                  );
                  setState(() => _overrideSelectedId = null);
                  widget.onSelect(null);
                  widget.onRefreshAll();
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Icon(Icons.home, size: 22, color: Colors.black),
              ),
              ...list.map((c) {
                final selected = _effectiveSelectedId == c.id;
                final label = (c.name ?? '').trim();
                final code = (c.code ?? '').trim();
                final first =
                    (code.isNotEmpty
                            ? code[0]
                            : (label.isNotEmpty ? label[0] : '•'))
                        .toUpperCase();
                return _avatarButton(
                  context: context,
                  tooltip: label.isEmpty && code.isEmpty
                      ? 'Société'
                      : '$label${code.isNotEmpty ? " ($code)" : ""}',
                  selected: selected,
                  showActiveBadge: (c.isActive == true),
                  onTap: () {
                    final next = selected ? null : c.id;
                    debugPrint('[CompaniesChipsRow] select company id="$next"');
                    setState(() => _overrideSelectedId = next);
                    widget.onSelect(next);
                  },
                  child: Text(
                    first,
                    style: const TextStyle(fontSize: 20, height: 1),
                  ),
                );
              }),
            ];

            return Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _separate(items, const SizedBox(width: 12)),
                ),
              ),
            );
          },
          loading: () => const _ChipsSkeleton(),
          error: (e, _) => Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    ref.refresh(marketplaceCompaniesProvider(widget.baseUri)),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _avatarButton({
  required BuildContext context,
  required String tooltip,
  required bool selected,
  required bool showActiveBadge,
  required VoidCallback onTap,
  required Widget child,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final ring = selected
      ? cs.primary.withOpacity(0.9)
      : (isDark ? Colors.white70 : cs.outline);
  final ringWidth = selected ? 2.4 : 1.2;
  final glow = selected ? cs.primary.withOpacity(0.25) : Colors.transparent;
  const glyphColor = Colors.black;
  final badgeBorder = isDark
      ? Colors.black
      : Theme.of(context).scaffoldBackgroundColor;

  return Semantics(
    button: true,
    selected: selected,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: ringWidth),
            boxShadow: [
              if (selected)
                BoxShadow(color: glow, blurRadius: 10, spreadRadius: 0.5),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: IconTheme.merge(
                  data: const IconThemeData(color: glyphColor, size: 22),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: glyphColor,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.white54,
                          blurRadius: 6,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
              if (showActiveBadge)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: badgeBorder, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<Widget> _separate(List<Widget> children, Widget separator) {
  if (children.isEmpty) return children;
  return List<Widget>.generate(
    children.length * 2 - 1,
    (i) => i.isEven ? children[i ~/ 2] : separator,
  );
}

class _ChipsSkeleton extends StatelessWidget {
  const _ChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ring = isDark ? Colors.white38 : cs.outlineVariant;

    final tiles = List.generate(
      6,
      (i) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 1.2),
        ),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          tiles.length * 2 - 1,
          (i) => i.isEven ? tiles[i ~/ 2] : const SizedBox(width: 12),
        ),
      ),
    );
  }
}
