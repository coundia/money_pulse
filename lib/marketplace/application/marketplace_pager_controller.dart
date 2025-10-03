// Pager with query/company filters, error handling, and per-item image index memory.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/marketplace_item.dart';
import '../infrastructure/marketplace_repo_provider.dart';

class MarketplacePagerState {
  final List<MarketplaceItem> items;
  final bool hasNext;
  final int page;
  final bool isLoading;
  final Set<String> saved;

  // Filters
  final String? query;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final String? statusesCsv;
  final String? companyId; // ✅ NEW

  // UI helpers
  final String? errorText;
  final Map<String, int> imageIndexByItem;

  const MarketplacePagerState({
    required this.items,
    required this.hasNext,
    required this.page,
    required this.isLoading,
    required this.saved,
    this.query,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.statusesCsv,
    this.companyId, // ✅
    this.errorText,
    required this.imageIndexByItem,
  });

  MarketplacePagerState copyWith({
    List<MarketplaceItem>? items,
    bool? hasNext,
    int? page,
    bool? isLoading,
    Set<String>? saved,
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? statusesCsv,
    String? companyId,
    String? errorText,
    Map<String, int>? imageIndexByItem,
  }) {
    return MarketplacePagerState(
      items: items ?? this.items,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      saved: saved ?? this.saved,
      query: query ?? this.query,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      statusesCsv: statusesCsv ?? this.statusesCsv,
      companyId: companyId ?? this.companyId, // ✅
      errorText: errorText,
      imageIndexByItem: imageIndexByItem ?? this.imageIndexByItem,
    );
  }

  static MarketplacePagerState initial() => const MarketplacePagerState(
    items: [],
    hasNext: true,
    page: 0,
    isLoading: false,
    saved: {},
    query: null,
    category: null,
    minPrice: null,
    maxPrice: null,
    statusesCsv: 'PUBLISH',
    companyId: null,
    errorText: null,
    imageIndexByItem: {},
  );
}

class MarketplacePager extends StateNotifier<MarketplacePagerState> {
  final Ref ref;
  final String baseUri;

  MarketplacePager(this.ref, this.baseUri)
    : super(MarketplacePagerState.initial()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      page: 0,
      items: [],
      errorText: null,
      // on garde imageIndexByItem vide pour une recherche fraîche
      imageIndexByItem: {},
    );
    final repo = ref.read(marketplaceRepoProvider(baseUri));
    try {
      final page0 = await repo.fetchPage(
        page: 0,
        q: state.query,
        category: state.category,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        statusesCsv: state.statusesCsv,
        companyId: state.companyId,
      );
      state = state.copyWith(
        // Selon ton repo: content/items. Utilise la propriété existante:
        items: page0.items, // supporte les deux noms
        hasNext: page0.hasNext,
        page: 0,
        isLoading: false,
        errorText: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorText: e.toString());
    }
  }

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasNext) return;
    state = state.copyWith(isLoading: true, errorText: null);
    final repo = ref.read(marketplaceRepoProvider(baseUri));
    try {
      final nextPage = state.page + 1;
      final res = await repo.fetchPage(
        page: nextPage,
        q: state.query,
        category: state.category,
        minPrice: state.minPrice,
        maxPrice: state.maxPrice,
        statusesCsv: state.statusesCsv,
        companyId: state.companyId, // ✅
      );
      final newItems = res.items;
      state = state.copyWith(
        items: [...state.items, ...newItems],
        hasNext: res.hasNext,
        page: nextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorText: e.toString());
    }
  }

  void toggleSaved(String id) {
    final s = Set<String>.from(state.saved);
    if (s.contains(id)) {
      s.remove(id);
    } else {
      s.add(id);
    }
    state = state.copyWith(saved: s);
  }

  void applyFilters({
    String? q,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? statusesCsv,
    String? companyId, // ✅
  }) {
    state = state.copyWith(
      query: q ?? state.query,
      category: category ?? state.category,
      minPrice: minPrice ?? state.minPrice,
      maxPrice: maxPrice ?? state.maxPrice,
      statusesCsv: statusesCsv ?? state.statusesCsv,
      companyId: companyId ?? state.companyId, // ✅
    );
    loadInitial();
  }

  void setImageIndex(String itemId, int index) {
    final map = Map<String, int>.from(state.imageIndexByItem);
    map[itemId] = index;
    state = state.copyWith(imageIndexByItem: map);
  }

  void reload() => loadInitial();
}

final marketplacePagerProvider = StateNotifierProvider.autoDispose
    .family<MarketplacePager, MarketplacePagerState, String>(
      (ref, baseUri) => MarketplacePager(ref, baseUri),
    );
