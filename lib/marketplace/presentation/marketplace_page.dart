// TikTok-like vertical marketplace page with top search, companies row filter,
// infinite vertical pager and right-drawer product details.
// Persist selected company; Refresh button clears ALL filters & reloads.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'product_view_panel.dart';
import 'widgets/companies_chips_row.dart';

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
    ref
        .read(marketplacePagerProvider(widget.baseUri).notifier)
        .applyFilters(q: q);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearSearch() {
    if (_searchCtrl.text.isEmpty) return;
    _searchCtrl.clear();
    ref
        .read(marketplacePagerProvider(widget.baseUri).notifier)
        .applyFilters(q: '');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketplacePagerProvider(widget.baseUri));
    final pager = ref.read(marketplacePagerProvider(widget.baseUri).notifier);

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
                if (index >= state.items.length - 2 && state.hasNext) {
                  pager.loadNext();
                }
              },
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _buildProductPage(context, item, state, pager);
              },
            ),

          // Barre de recherche
          Positioned(
            top: 8 + MediaQuery.of(context).padding.top,
            left: 8,
            right: 8,
            child: _TopSearchPill(
              controller: _searchCtrl,
              onSubmit: _applySearch,
              onClear: _clearSearch,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),

          // Rangée des sociétés
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: CompaniesChipsRow(
              baseUri: widget.baseUri,
              selectedId: _selectedCompanyId,
              onSelect: (id) {
                setState(() => _selectedCompanyId = id);
                // 🔹 Utilise la nouvelle API claire
                if (id == null) {
                  pager.setCompanyFilter(null); // => liste tous
                } else {
                  pager.setCompanyFilter(id);
                }
              },
              onRefreshAll: () {
                _searchCtrl.clear();
                pager.resetAll(); // enlève tous les filtres
                setState(() => _selectedCompanyId = null);
              },
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

  Widget _buildProductPage(
    BuildContext context,
    MarketplaceItem item,
    MarketplacePagerState state,
    MarketplacePager notifier,
  ) {
    final theme = Theme.of(context);
    final urls = item.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final multiple = urls.length > 1;
    final imagesCtrl = PageController();

    final safeBottom = MediaQuery.of(context).padding.bottom;
    const ctaHeight = 44.0;
    const ctaSpacing = 16.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (urls.isNotEmpty)
          PageView.builder(
            controller: imagesCtrl,
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            itemBuilder: (_, i) {
              final u = urls[i];
              return FadeInImage.assetNetwork(
                placeholder: 'assets/transparent_1px.png',
                image: u,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                imageErrorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Colors.black),
              );
            },
          )
        else
          const ColoredBox(color: Colors.black),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
                Colors.black.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        if (multiple)
          Positioned(
            right: 16,
            bottom: ctaSpacing + safeBottom + ctaHeight + 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${urls.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          left: 16,
          bottom: (ctaSpacing * 4) + safeBottom,
          right: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatters.amountFromCents(item.defaultPrice * 100)} FCFA',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((item.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),

        Positioned(
          right: 20,
          bottom: (ctaSpacing * 4) + safeBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionBtn(
                icon: Icons.visibility,
                label: 'Détails',
                onTap: () => showRightDrawer(
                  context,
                  child: ProductViewPanel(item: item),
                ),
              ),
              const SizedBox(height: 16),
              _actionBtn(
                icon: Icons.share,
                label: 'Partager',
                onTap: () => _snack(context, 'Partager ${item.name}'),
              ),
            ],
          ),
        ),

        Positioned(
          right: 16,
          bottom: 16 + safeBottom,
          child: SizedBox(
            height: ctaHeight,
            child: FilledButton.icon(
              onPressed: () => _snack(context, 'Commander ${item.name}'),
              icon: const Icon(Icons.shopping_bag),
              label: const Text('Commander'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  void _snack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ---------- UI: Top Search Pill ---------- */

class _TopSearchPill extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const _TopSearchPill({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final showClear = controller.text.isNotEmpty;

    return Row(
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.white.withOpacity(0.08),
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white70,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit…',
                    hintStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rechercher',
                          onPressed: onSubmit,
                          icon: const Icon(Icons.search, color: Colors.white),
                        ),
                        if (showClear)
                          IconButton(
                            tooltip: 'Effacer',
                            onPressed: onClear,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
