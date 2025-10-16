// Vertical marketplace feed page with search, companies filter, lazy paging,
// image spinner, and bottom-sheet actions (no right drawer).

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/marketplace/presentation/order_quick_panel.dart';
import '../../presentation/shared/haptics_util.dart';
import '../../shared/constants/env.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'widgets/companies_chips_row.dart';
import 'message_compose_panel.dart';
import 'widgets/top_search_pill.dart';
import 'widgets/product_info_compact.dart';
import 'widgets/shop_message_pill.dart';
import 'widgets/action_bubble.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  final String baseUri;
  const MarketplacePage({super.key, this.baseUri = Env.BASE_URI});

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

  // ---------- Bottom-sheet helpers (replace right drawer) --------------------

  Future<void> _openOrderSheet(
    BuildContext context,
    MarketplaceItem item,
  ) async {
    final h = MediaQuery.of(context).size.height;
    // Keep same feel: 50% screen height (like your suggestedHeightFraction)
    final heightFactor = OrderQuickPanel.suggestedHeightFraction; // 0.50
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetContainer(
          height: h * heightFactor,
          child: OrderQuickPanel(item: item, baseUri: widget.baseUri),
        );
      },
    );
  }

  Future<void> _openMessageSheet(
    BuildContext context,
    MarketplaceItem item,
  ) async {
    final h = MediaQuery.of(context).size.height;
    // Half-screen to match prior UX
    const heightFactor = 0.50;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetContainer(
          height: h * heightFactor,
          child: MessageComposePanel(item: item, baseUri: widget.baseUri),
        );
      },
    );
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
    final urls = item.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final firstUrl = urls.isNotEmpty ? urls.first : null;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final int unitXof = item.defaultPrice;
    final bool showPrice = unitXof > 1;
    final bool outOfStock = (item.quantity ?? 0) <= 0;
    final bool hideCommandAndSold = outOfStock && !showPrice;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (firstUrl != null)
          Image.network(
            firstUrl,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              final isLoading = loadingProgress != null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  if (!isLoading) child,
                  if (isLoading)
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              );
            },
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
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
        Positioned(
          left: 12,
          right: 0,
          bottom: 12 + safeBottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductInfoCompact(
                      name: item.name,
                      priceStr: showPrice
                          ? '${Formatters.amountFromCents(item.defaultPrice)} FCFA'
                          : '',
                      priceXof: item.defaultPrice,
                      description: item.description,
                      theme: Theme.of(context),
                    ),
                    const SizedBox(height: 8),
                    ShopMessagePill(
                      shopName: _shopName(item),
                      onTap: () async {
                        debugPrint(
                          '[MarketplacePage] open Message sheet for "${item.name}"',
                        );
                        HapticsUtil.vibrate();
                        await _openMessageSheet(context, item);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                              '[MarketplacePage] open order sheet for item="${item.name}" unit=${item.defaultPrice}XOF',
                            );
                            HapticsUtil.vibrate();
                            _openOrderSheet(context, item);
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
    return 'Message • Boutique';
  }
}

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
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Common container for the modal bottom sheets to emulate a drawer look,
/// with rounded top corners, safe area, and a fixed height.
class _BottomSheetContainer extends StatelessWidget {
  final double height;
  final Widget child;
  const _BottomSheetContainer({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: cs.surface,
          elevation: 10,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(height: height, width: double.infinity, child: child),
        ),
      ),
    );
  }
}
