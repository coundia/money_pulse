import 'package:flutter/material.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final PageController _pageCtrl = PageController();
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _items = [
    {
      "title": "Ordinateur portable",
      "price": 250000,
      "seller": "Aliou",
      "image": "https://picsum.photos/600/900?1",
    },
    {
      "title": "Chaussures Nike",
      "price": 15000,
      "seller": "Aminata",
      "image": "https://picsum.photos/600/900?2",
    },
    {
      "title": "Téléphone Samsung",
      "price": 120000,
      "seller": "Moussa",
      "image": "https://picsum.photos/600/900?3",
    },
    {
      "title": "Sac en cuir",
      "price": 30000,
      "seller": "Khady",
      "image": "https://picsum.photos/600/900?4",
    },
  ];

  final Set<String> _savedItems = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final isSaved = _savedItems.contains(item["title"]);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item["image"],
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
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
                  // Infos produit
                  Positioned(
                    left: 16,
                    bottom: 100,
                    right: 100, // laisse la place aux boutons
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["title"],
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${item["price"]} FCFA",
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Vendeur : ${item["seller"]}",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions latérales (style TikTok)
                  Positioned(
                    right: 20,
                    bottom: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionBtn(
                          icon: Icons.favorite,
                          label: "Aimer",
                          active: false,
                          onTap: () => _snack(context, "Aimé ${item["title"]}"),
                        ),
                        const SizedBox(height: 16),
                        _actionBtn(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border_outlined,
                          label: "Sauver",
                          active: isSaved,
                          onTap: () {
                            setState(() {
                              if (isSaved) {
                                _savedItems.remove(item["title"]);
                              } else {
                                _savedItems.add(item["title"]);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _actionBtn(
                          icon: Icons.comment,
                          label: "Commentaires",
                          onTap: () => _showComments(context, item["title"]),
                        ),
                        const SizedBox(height: 16),
                        _actionBtn(
                          icon: Icons.shopping_bag,
                          label: "Commander",
                          onTap: () =>
                              _snack(context, "Commande ${item["title"]}"),
                        ),
                        const SizedBox(height: 16),
                        _actionBtn(
                          icon: Icons.share,
                          label: "Partager",
                          onTap: () =>
                              _snack(context, "Partager ${item["title"]}"),
                        ),
                        const SizedBox(height: 16),
                        _actionBtn(
                          icon: Icons.skip_next,
                          label: "Ignorer",
                          onTap: () {
                            if (index < _items.length - 1) {
                              _pageCtrl.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _snack(context, "Dernier produit atteint");
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Barre retour + recherche
          Positioned(
            top: 40,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black54,
                      hintText: "Rechercher un produit...",
                      hintStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (query) =>
                        _snack(context, "Recherche : $query"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  void _showComments(BuildContext context, String product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Commentaires sur $product",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: const [
                    Text(
                      "💬 Moussa: Très bon produit",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "💬 Aminata: Livraison rapide !",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "💬 Khady: Je recommande ✅",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
