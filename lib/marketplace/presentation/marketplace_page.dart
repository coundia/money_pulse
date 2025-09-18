// TikTok-like vertical marketplace page consuming REST API with infinite scroll and right-drawer details.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'product_view_panel.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  final String baseUri;
  const MarketplacePage({super.key, this.baseUri = 'http://127.0.0.1:8095'});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  final PageController _pageCtrl = PageController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
                if (index >= state.items.length - 2 && state.hasNext) {
                  notifier.loadNext();
                }
              },
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _buildProductPage(context, item, state, notifier);
              },
            ),
          _buildTopBar(context),
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

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 40,
      left: 8,
      right: 8,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Retour',
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black54,
                hintText: 'Rechercher un produit…',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onSubmitted: (_) {},
              textInputAction: TextInputAction.search,
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
    final isSaved = state.saved.contains(item.id);
    final img = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    final multiple = item.imageUrls.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (img != null)
          Image.network(
            img,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
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
            top: 56,
            right: 56,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.imageUrls.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          left: 16,
          bottom: 100,
          right: 100,
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
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionBtn(
                icon: Icons.favorite,
                label: 'Aimer',
                active: false,
                onTap: () => _snack(context, 'Aimé ${item.name}'),
              ),
              const SizedBox(height: 16),
              _actionBtn(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                label: isSaved ? 'Sauvé' : 'Sauver',
                active: isSaved,
                onTap: () => notifier.toggleSaved(item.id),
              ),
              const SizedBox(height: 16),
              _actionBtn(
                icon: Icons.visibility,
                label: 'Détails',
                onTap: () {
                  showRightDrawer(context, child: ProductViewPanel(item: item));
                },
              ),
              const SizedBox(height: 16),
              _actionBtn(
                icon: Icons.shopping_bag,
                label: 'Commander',
                onTap: () => _snack(context, 'Commande ${item.name}'),
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
          top: 48,
          right: 12,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'view',
                child: Text('Voir les détails'),
              ),
              PopupMenuItem(
                value: isSaved ? 'unsave' : 'save',
                child: Text(isSaved ? 'Retirer des favoris' : 'Sauver'),
              ),
              const PopupMenuItem(value: 'report', child: Text('Signaler')),
              const PopupMenuItem(value: 'share', child: Text('Partager')),
            ],
            onSelected: (v) {
              if (v == 'view') {
                showRightDrawer(context, child: ProductViewPanel(item: item));
              } else if (v == 'save' || v == 'unsave') {
                notifier.toggleSaved(item.id);
              } else if (v == 'share') {
                _snack(context, 'Partager ${item.name}');
              } else if (v == 'report') {
                _snack(context, 'Signalé ${item.name}');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.green : Colors.black54,
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
