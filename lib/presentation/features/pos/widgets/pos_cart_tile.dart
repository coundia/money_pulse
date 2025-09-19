// Minimal POS product tile with tap flash, optional top image,
// top-left added check, bottom-left quantity badge, bottom-right decrement button,
// and safe menu placement.

import 'dart:io';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class PosProductTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final int? stockQty;
  final bool isAdded;
  final int addedQty;
  final String? imagePath; // local path if available
  final String? imageUrl; // remote url fallback
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDecrement;
  final Future<void> Function(String action)? onMenuAction;

  const PosProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.stockQty,
    this.isAdded = false,
    this.addedQty = 0,
    this.imagePath,
    this.imageUrl,
    this.onTap,
    this.onLongPress,
    this.onDecrement,
    this.onMenuAction,
  });

  @override
  State<PosProductTile> createState() => _PosProductTileState();
}

class _PosProductTileState extends State<PosProductTile> {
  bool _flash = false;
  bool _hover = false;

  String get _price => Formatters.amountFromCents(widget.priceCents);

  Color _stockBg(int qty, ColorScheme cs) =>
      qty > 0 ? cs.primaryContainer : cs.surface;

  Color _stockFg(int qty, ColorScheme cs) =>
      qty > 0 ? cs.onPrimaryContainer : cs.onSurfaceVariant;

  Future<void> _showMenuAtOffset(BuildContext context, Offset globalPos) async {
    if (widget.onMenuAction == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        overlay.size.width - globalPos.dx,
        overlay.size.height - globalPos.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'add1',
          child: ListTile(
            leading: Icon(Icons.add_shopping_cart),
            title: Text('Ajouter (×1)'),
          ),
        ),
        PopupMenuItem(
          value: 'qty',
          child: ListTile(
            leading: Icon(Icons.onetwothree),
            title: Text('Choisir quantité…'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'details',
          child: ListTile(
            leading: Icon(Icons.visibility_outlined),
            title: Text('Détails'),
          ),
        ),
      ],
    );
    if (result != null) {
      await widget.onMenuAction!(result);
    }
  }

  void _flashOnce() {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  void _handleTap() {
    _flashOnce();
    widget.onTap?.call();
  }

  Widget? _buildTopImage() {
    // Prefer local file, fallback to remote
    if (widget.imagePath != null &&
        widget.imagePath!.isNotEmpty &&
        File(widget.imagePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 1.6, // wide banner-ish
          child: Image.file(
            File(widget.imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.image_not_supported_outlined)),
          ),
        ),
      );
    }
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Image.network(
            widget.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.image_not_supported_outlined)),
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qty = widget.stockQty ?? 0;

    final bgBase = cs.surface;
    final flashBg = cs.primaryContainer.withOpacity(.22);
    final hoverBg = cs.surfaceVariant.withOpacity(.14);
    final addedBg = cs.primaryContainer.withOpacity(.28);

    final bgColor = _flash
        ? flashBg
        : widget.isAdded
        ? addedBg
        : _hover
        ? hoverBg
        : bgBase;

    final borderColor = widget.isAdded
        ? cs.primary.withOpacity(.48)
        : cs.outlineVariant.withOpacity(.5);

    final initial =
        (widget.title.isNotEmpty ? widget.title.characters.first : '?')
            .toUpperCase();

    final stockBadge = qty > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _stockBg(qty, cs),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Stock: $qty',
              style: TextStyle(
                color: _stockFg(qty, cs),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          )
        : const SizedBox.shrink();

    final needsBottomControls =
        (widget.addedQty > 0) || (widget.onDecrement != null);

    final topImage = _buildTopImage();

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onSecondaryTapDown: (d) => _showMenuAtOffset(context, d.globalPosition),
        onLongPressStart: (d) => _showMenuAtOffset(context, d.globalPosition),
        onLongPress: widget.onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _handleTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      10,
                      10,
                      10,
                      needsBottomControls ? 48 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (topImage != null) ...[
                          topImage,
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            if (topImage == null) ...[
                              CircleAvatar(radius: 18, child: Text(initial)),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                _price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Actions',
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {
                                final box =
                                    context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final pos = box.localToGlobal(
                                  Offset(box.size.width - 8, 36),
                                );
                                _showMenuAtOffset(context, pos);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const Spacer(),
                        if (qty > 0) stockBadge,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Added check
            Positioned(
              left: 8,
              top: 8,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: widget.isAdded ? 1.0 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),

            // Quantity badge
            if (widget.addedQty > 0)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.primary, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '×${widget.addedQty}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),

            // Decrement button
            if (widget.onDecrement != null)
              Positioned(
                right: 8,
                bottom: 6,
                child: IconButton.filledTonal(
                  onPressed: widget.onDecrement,
                  tooltip: 'Retirer 1',
                  icon: const Icon(Icons.remove),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
