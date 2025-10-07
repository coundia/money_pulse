// Vertical marketplace feed with search and companies filter.
// TikTok-like layout: top-left search, companies chips; each product shows a single image.
// Bottom-left: "Message • <Boutique>" au-dessus des infos produit; à droite: bulle "Commander".
// "Message" ouvre un drawer pour éditer puis enregistre via l'API (typeOrder="MESSAGE").
// Si item.quantity == 0 => masquer "Commander" + badge "Rupture de stock".
// Si item.defaultPrice <= 1 => masquer le prix.
// Logs des interactions + payload API; "ALL" force un reload frais.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/marketplace/presentation/order_quick_panel.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'widgets/companies_chips_row.dart';

// Panels / widgets découpés (SRP)
import 'message_compose_panel.dart';
import 'widgets/top_search_pill.dart';
import 'widgets/product_info_compact.dart';
import 'widgets/shop_message_pill.dart';
import 'widgets/action_bubble.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  final String baseUri;
  const MarketplacePage({super.key, this.baseUri = 'http://127.0.0.1:8095'});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final PageController _pageCtrl = PageController();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim();
    debugPrint('[MarketplacePage] applySearch q="$q"');
    ref
        .read(marketplacePagerProvider(widget.baseUri).notifier)
        .applyFilters(q: q);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearSearch() {
    if (_searchCtrl.text.isEmpty) return;
    debugPrint('[MarketplacePage] clearSearch');
    _searchCtrl.clear();
    ref
        .read(marketplacePagerProvider(widget.baseUri).notifier)
        .applyFilters(q: null);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _refreshAll() {
    debugPrint(
      '[MarketplacePage] refreshAll -> invalidate pager & reset UI filters',
    );
    setState(() => _selectedCompanyId = null);
    _searchCtrl.clear();
    ref.invalidate(marketplacePagerProvider(widget.baseUri));
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplacePagerProvider(widget.baseUri));
    final notifier = ref.read(
      marketplacePagerProvider(widget.baseUri).notifier,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (state.items.isEmpty && state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.items.isEmpty)
            Center(
              child: Text(
                'Aucun produit pour le moment',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white70),
              ),
            )
          else
            PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: state.items.length,
              onPageChanged: (index) {
                debugPrint(
                  '[MarketplacePage] onPageChanged index=$index/${state.items.length - 1}',
                );
                if (index >= state.items.length - 2 && state.hasNext) {
                  debugPrint('[MarketplacePage] nearing end -> loadNext()');
                  notifier.loadNext();
                }
              },
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _buildProductPage(context, item);
              },
            ),

          // Search pill
          Positioned(
            top: 8 + MediaQuery.of(context).padding.top,
            left: 8,
            right: 8,
            child: TopSearchPill(
              controller: _searchCtrl,
              onSubmit: _applySearch,
              onClear: _clearSearch,
              onBack: () {
                debugPrint('[MarketplacePage] back from search pill');
                Navigator.of(context).maybePop();
              },
            ),
          ),

          // Companies row
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: CompaniesChipsRow(
              baseUri: widget.baseUri,
              selectedId: _selectedCompanyId,
              onSelect: (id) {
                setState(() => _selectedCompanyId = id);
                if (id != null) {
                  debugPrint('[MarketplacePage] select company id="$id"');
                  ref
                      .read(marketplacePagerProvider(widget.baseUri).notifier)
                      .applyFilters(companyId: id);
                }
              },
              onRefreshAll: _refreshAll,
            ),
          ),

          if (state.isLoading)
            const Positioned(
              right: 16,
              bottom: 16,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductPage(BuildContext context, MarketplaceItem item) {
    final theme = Theme.of(context);
    final urls = item.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final firstUrl = urls.isNotEmpty ? urls.first : null;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // Règles d’affichage
    final int unitXof = item.defaultPrice; // prix unitaire en XOF (entier)
    final bool showPrice = unitXof > 1; // <-- affiche SEULEMENT si > 1
    final bool outOfStock =
        (item.quantity ?? 0) <= 0; // si 0 => masquer “Commander” & informer

    final bool hideCommandAndSold = outOfStock && !showPrice;

    final String priceStr = showPrice
        ? '${Formatters.amountFromCents(unitXof * 100)} FCFA'
        : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (firstUrl != null)
          FadeInImage.assetNetwork(
            placeholder: 'assets/transparent_1px.png',
            image: firstUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 180),
            imageErrorBuilder: (_, __, ___) =>
                const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),

        // Gradient overlays
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.75),
                Colors.transparent,
                Colors.black.withOpacity(0.92),
              ],
              stops: const [0.0, 0.45, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Bottom bar: message+infos (gauche) / commander (droite ou badge rupture)
        Positioned(
          left: 12,
          right: 0,
          bottom: 12 + safeBottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left: infos + message (ouvre le drawer)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductInfoCompact(
                      name: item.name,
                      priceStr:
                          '${Formatters.amountFromCents(item.defaultPrice * 100)} FCFA',
                      priceXof: item
                          .defaultPrice, // le prix s’affichera seulement si > 1
                      description: item.description,
                      theme: Theme.of(context),
                    ),

                    const SizedBox(height: 8),
                    ShopMessagePill(
                      shopName: _shopName(item),
                      onTap: () async {
                        debugPrint(
                          '[MarketplacePage] open Message drawer for "${item.name}"',
                        );
                        final w = MediaQuery.of(context).size.width;
                        final widthFraction = w < 520 ? 0.96 : 0.62;
                        await showRightDrawer(
                          context,
                          widthFraction: widthFraction,
                          heightFraction: 0.50,
                          child: MessageComposePanel(
                            item: item,
                            baseUri: widget.baseUri,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right: “Commander” (si dispo) sinon badge rupture —
              // et si hideCommandAndSold == true, on masque totalement la zone de droite.
              if (hideCommandAndSold)
                const SizedBox.shrink()
              else
                Align(
                  alignment: Alignment.bottomRight,
                  child: outOfStock
                      ? const _OutOfStockBadge()
                      : ActionBubble(
                          icon: Icons.shopping_bag,
                          label: 'Commander',
                          gradient: const [
                            Color(0xFF00C853),
                            Color(0xFF66BB6A),
                          ],
                          onTap: () {
                            debugPrint(
                              '[MarketplacePage] open order panel for item="${item.name}" unit=${item.defaultPrice}XOF',
                            );
                            final w = MediaQuery.of(context).size.width;
                            final widthFraction = w < 520
                                ? 0.96
                                : OrderQuickPanel.suggestedWidthFraction;
                            showRightDrawer(
                              context,
                              widthFraction: widthFraction,
                              heightFraction:
                                  OrderQuickPanel.suggestedHeightFraction,
                              child: OrderQuickPanel(
                                item: item,
                                baseUri: widget.baseUri,
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _shopName(MarketplaceItem item) {
    // TODO: si votre modèle expose le nom de la boutique: item.companyName ?? ...
    return 'Message • Boutique';
  }
}

// Petit badge “Rupture de stock” (à droite)
class _OutOfStockBadge extends StatelessWidget {
  const _OutOfStockBadge();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.do_not_disturb_alt, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Rupture de stock',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 18), // garde une hauteur proche de la bulle
      ],
    );
  }
}
