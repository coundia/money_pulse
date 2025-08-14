// POS product grid tile with price, stock badge, and acontext menu for quick actions.
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class PosProductTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int priceCents;
  final int? stockQty;
  final VoidCallback? onTap; // add 1 to cart
  final VoidCallback? onLongPress; // open qty chooser drawer
  final Future<void> Function(String action)? onMenuAction;

  const PosProductTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.priceCents,
    this.stockQty,
    this.onTap,
    this.onLongPress,
    this.onMenuAction,
  });

  String get _price => Formatters.amountFromCents(priceCents);

  Color _stockBg(int qty, ColorScheme cs) =>
      qty > 0 ? cs.primaryContainer : cs.errorContainer.withOpacity(.35);

  Color _stockFg(int qty, ColorScheme cs) =>
      qty > 0 ? cs.onPrimaryContainer : cs.onErrorContainer;

  Future<void> _showMenu(BuildContext context, Offset globalPos) async {
    if (onMenuAction == null) return;
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
      await onMenuAction!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qty = stockQty ?? 0;

    final stockBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _stockBg(qty, cs),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        qty > 0 ? 'Stock: $qty' : 'Rupture',
        style: TextStyle(
          color: _stockFg(qty, cs),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showMenu(context, d.globalPosition),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // header row: avatar + stock + price
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      (title.isNotEmpty ? title.characters.first : '?')
                          .toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: stockBadge),
                  const SizedBox(width: 8),
                  Text(
                    _price,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const Spacer(),
              // primary action
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
