// Vertical marketplace feed with search and companies filter.
// TikTok-like layout: top-left search, companies chips; each product shows a single image.
// Bottom-left: a pill "Message • <Boutique>" above compact product info; bottom-right: "Commander" bubble.
// WhatsApp launcher is robust (native scheme first, then web fallback).
// Logs key interactions; "ALL" invalidates the pager to force a fresh API reload.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:money_pulse/marketplace/presentation/order_quick_panel.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
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
            child: _TopSearchPill(
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Single image (first URL)
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

        // Bottom bar: Shop message pill (top-left) + product info (left) + Commander (right)
        Positioned(
          left: 12,
          right: 0, // <-- pour coller à l'extrême droite
          bottom: 12 + safeBottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Gauche : Message pill + infos produit
              Expanded(
                // <-- prend tout l’espace restant
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductInfoCompact(
                      name: item.name,
                      priceStr:
                          '${Formatters.amountFromCents(item.defaultPrice * 100)} FCFA',
                      description: item.description,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _ShopMessagePill(
                      shopName: _shopName(item),
                      onTap: () async {
                        debugPrint(
                          '[MarketplacePage] message seller item="${item.name}" id=${item.id}',
                        );
                        final text =
                            'Bonjour, je suis intéressé par "${item.name}" à '
                            '${Formatters.amountFromCents(item.defaultPrice * 100)} FCFA.';
                        await _openWhatsApp(context, text);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Droite : bouton Commander collé au bord
              Align(
                alignment: Alignment.bottomRight,
                child: _ActionBubble(
                  icon: Icons.shopping_bag,
                  label: 'Commander',
                  gradient: const [Color(0xFF00C853), Color(0xFF66BB6A)],
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
                      heightFraction: OrderQuickPanel.suggestedHeightFraction,
                      child: OrderQuickPanel(item: item),
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

  // Replace with your real shop field (e.g. item.companyName) if available.
  String _shopName(MarketplaceItem item) {
    // TODO: use item.companyName / item.company?.name / item.sellerName if your model exposes it
    return 'Envoyer un message';
  }

  /// Robust WhatsApp launcher: native scheme first, then web fallback (avoids canLaunchUrl on iOS).
  Future<void> _openWhatsApp(BuildContext context, String message) async {
    final encoded = Uri.encodeComponent(message);
    final native = Uri.parse('whatsapp://send?text=$encoded');
    final web = Uri.parse('https://wa.me/?text=$encoded');

    try {
      final ok = await launchUrl(
        native,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (ok) return;
    } catch (e) {
      debugPrint('[MarketplacePage] WhatsApp native launch failed: $e');
    }

    try {
      final ok = await launchUrl(web, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('[MarketplacePage] WhatsApp web launch failed: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp introuvable sur cet appareil')),
    );
  }
}

/* ---------- Compact product info (bottom-left) ---------- */

class _ProductInfoCompact extends StatelessWidget {
  final String name;
  final String priceStr;
  final String? description;
  final ThemeData theme;

  const _ProductInfoCompact({
    required this.name,
    required this.priceStr,
    required this.theme,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2, top: 2, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            // Price
            Text(
              priceStr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            if ((description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ---------- UI: Shop Message Pill (TikTok-like) ---------- */

class _ShopMessagePill extends StatefulWidget {
  final String shopName;
  final VoidCallback onTap;

  const _ShopMessagePill({required this.shopName, required this.onTap});

  @override
  State<_ShopMessagePill> createState() => _ShopMessagePillState();
}

class _ShopMessagePillState extends State<_ShopMessagePill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Message ${widget.shopName}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          Feedback.forTap(context);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
              children: [
                Text(
                  '${widget.shopName} ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.send, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- UI: Action Bubble (Commander) ---------- */

class _ActionBubble extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionBubble({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionBubble> createState() => _ActionBubbleState();
}

class _ActionBubbleState extends State<_ActionBubble> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: widget.label,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: () {
              Feedback.forTap(context);
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
