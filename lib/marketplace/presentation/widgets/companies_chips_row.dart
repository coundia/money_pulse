// Avatar-only horizontal companies row: "Refresh" clears selection immediately,
// transparent icons, centered layout, with active (green) badge like Facebook.
// Company logo (first letter / icon) is BLACK and remains visible on dark bg
// thanks to a subtle white glow on text glyphs.
//
// Path: marketplace/presentation/widgets/companies_chips_row.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/marketplace_company_provider.dart';

class CompaniesChipsRow extends ConsumerStatefulWidget {
  final String baseUri;
  final String? selectedId;
  final void Function(String? id) onSelect;

  const CompaniesChipsRow({
    super.key,
    required this.baseUri,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  ConsumerState<CompaniesChipsRow> createState() => _CompaniesChipsRowState();
}

class _CompaniesChipsRowState extends ConsumerState<CompaniesChipsRow> {
  final _scrollCtrl = ScrollController();
  String? _overrideSelectedId; // optimistic selection visual override

  @override
  void didUpdateWidget(covariant CompaniesChipsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      _overrideSelectedId = null; // keep in sync with parent
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
              // ⟳ REFRESH — deselect everything and reload
              _avatarButton(
                context: context,
                tooltip: 'Rafraîchir (tout afficher)',
                selected: false,
                showActiveBadge: false,
                onTap: () async {
                  Feedback.forTap(context);
                  setState(() => _overrideSelectedId = null); // UI instant
                  widget.onSelect(null); // notify parent (all companies)
                  ref.invalidate(marketplaceCompaniesProvider(widget.baseUri));
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Icon(
                  Icons.refresh,
                  size: 22,
                ), // black via IconTheme
              ),

              // Companies
              ...list.map((c) {
                final selected = _effectiveSelectedId == c.id;
                final t =
                    (c.code?.trim().isNotEmpty == true
                            ? c.code!.trim()[0]
                            : (c.name?.trim().isNotEmpty == true
                                  ? c.name!.trim()[0]
                                  : '•'))
                        .toUpperCase();

                return _avatarButton(
                  context: context,
                  tooltip: '${c.name} (${c.code})',
                  selected: selected,
                  showActiveBadge: c.isActive == true, // green badge if active
                  onTap: () {
                    Feedback.forTap(context);
                    final next = selected ? null : c.id; // toggle selection
                    setState(() => _overrideSelectedId = next);
                    widget.onSelect(next);
                  },
                  // Letter logo — black + subtle white glow for visibility
                  child: Text(
                    t,
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

  /// Avatar button with transparent background, selectable ring, and optional
  /// green "active" badge (bottom-right). Logo/Icons are forced to BLACK.
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

    // BLACK glyph (letter/icon), with subtle white glow for text glyphs only.
    const glyphColor = Colors.black;
    final textGlow = [
      Shadow(
        color: Colors.white54, // soft halo to remain visible on dark bg
        blurRadius: 6,
        offset: Offset(0, 0),
      ),
    ];

    // Border around the green badge to detach from background
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
              color: Colors.transparent, // keep transparent background
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
                // Centered glyph
                Center(
                  child: IconTheme.merge(
                    data: const IconThemeData(color: glyphColor, size: 22),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: glyphColor,
                        fontWeight: FontWeight.w600,
                        // Add glow only for text glyphs; Icons will ignore it.
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

                // Active badge (bottom-right)
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
