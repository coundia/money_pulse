// Vertical marketplace feed with search and companies filter.
// TikTok-like layout: top-left search, companies chips; each product shows a single image.
// Bottom-left: "Message • <Boutique>" au-dessus des infos produit; à droite: bulle "Commander".
// "Message" ouvre un drawer pour éditer puis enregistre via l'API (typeOrder="MESSAGE").
// Logs des interactions + payload API; "ALL" force un reload frais.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/marketplace/presentation/order_quick_panel.dart';
import '../../presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../application/marketplace_pager_controller.dart';
import '../domain/entities/marketplace_item.dart';
import 'widgets/companies_chips_row.dart';

// --- API request bits ---
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/marketplace/domain/entities/order_command_request.dart';
import 'package:money_pulse/marketplace/infrastructure/order_command_repo_provider.dart';

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

        // Bottom bar: Shop message pill + product info (left) / Commander (right)
        Positioned(
          left: 12,
          right: 0,
          bottom: 12 + safeBottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // LEFT: infos + bouton message (ouvre le drawer d’édition)
              Expanded(
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

              // RIGHT: bouton Commander collé au bord
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

  // Remplace avec le vrai nom de la boutique si dispo dans ton modèle.
  String _shopName(MarketplaceItem item) {
    // e.g. return item.companyName ?? 'Boutique';
    return 'Message • Boutique';
  }
}

/* ---------- Drawer: composer le message avant envoi ---------- */

class MessageComposePanel extends ConsumerStatefulWidget {
  final MarketplaceItem item;
  final String baseUri;
  const MessageComposePanel({
    super.key,
    required this.item,
    required this.baseUri,
  });

  static const double suggestedWidthFraction = 0.62;
  static const double suggestedHeightFraction = 0.50;

  @override
  ConsumerState<MessageComposePanel> createState() =>
      _MessageComposePanelState();
}

class _MessageComposePanelState extends ConsumerState<MessageComposePanel> {
  final _formKey = GlobalKey<FormState>();
  final _identCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Prefill depuis la session + message par défaut
    final grant = ref.read(accessSessionProvider);
    final prefIdent = (grant?.phone?.trim().isNotEmpty == true)
        ? grant!.phone!.trim()
        : (grant?.username?.trim() ?? '');
    _identCtrl.text = prefIdent;
    _messageCtrl.text =
        'Bonjour, je suis intéressé par "${widget.item.name}" '
        'à ${Formatters.amountFromCents(widget.item.defaultPrice * 100)} FCFA.';
  }

  @override
  void dispose() {
    _identCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sending) return;

    final grant = ref.read(accessSessionProvider);

    // Construire le payload API typeOrder = MESSAGE
    final payload = OrderCommandRequest(
      productId: widget.item.id,
      userId: grant?.id, // adapte si ta session expose un id
      identifiant: _identCtrl.text.trim(),
      telephone: grant?.phone,
      mail: grant?.email,
      ville: null,
      remoteId: null,
      localId: null,
      status: null,
      buyerName: grant?.username,
      address: null,
      notes: null,
      message: _messageCtrl.text.trim(), // <-- message édité
      typeOrder: 'MESSAGE', // <-- important
      paymentMethod: 'NA',
      deliveryMethod: 'NA',
      amountCents: widget.item.defaultPrice * 100,
      quantity: 1,
      dateCommand: DateTime.now().toUtc(),
    );

    // Log exhaustif du payload
    debugPrint(
      '[MessageComposePanel] about to send MESSAGE payload=${payload.toJson()}',
    );

    setState(() => _sending = true);
    try {
      await ref.read(orderCommandRepoProvider(widget.baseUri)).send(payload);
      if (!mounted) return;

      Navigator.of(context).maybePop(); // fermer le drawer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message enregistré, nous vous recontactons.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec enregistrement du message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: AppBar(
                elevation: 0,
                centerTitle: false,
                titleSpacing: 12,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message au vendeur',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextFormField(
                    controller: _identCtrl,
                    enabled: !_sending,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone ou email',
                      hintText: 'Téléphone ou email',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Téléphone ou email requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageCtrl,
                    enabled: !_sending,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Votre message…',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message requis'
                        : null,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Envoi…' : 'Envoyer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

/* ---------- UI: Shop Message Pill ---------- */

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
      label: widget.shopName,
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
              children: const [
                Text(
                  'Envoyer un message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.send, color: Colors.white, size: 18),
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
