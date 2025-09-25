// Riverpod pager controller with query/filters, error handling, and per-item image index memory.
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

  // UI helpers
  final String? errorText;
  final Map<String, int> imageIndexByItem; // itemId -> image page index

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
      );
      state = state.copyWith(
        items: page0.items,
        hasNext: page0.hasNext,
        page: 0,
        isLoading: false,
        errorText: null,
        imageIndexByItem: {}, // reset mapping
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
      );
      state = state.copyWith(
        items: [...state.items, ...res.items],
        hasNext: res.hasNext,
        page: nextPage,
        isLoading: false,
      );
    } catch (e) {
      // conserve la page, mais montre l'erreur
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

  // Set filters and reload from page 0
  void applyFilters({
    String? q,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? statusesCsv,
  }) {
    state = state.copyWith(
      query: q ?? state.query,
      category: category ?? state.category,
      minPrice: minPrice ?? state.minPrice,
      maxPrice: maxPrice ?? state.maxPrice,
      statusesCsv: statusesCsv ?? state.statusesCsv,
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
    .family<MarketplacePager, MarketplacePagerState, String>((ref, baseUri) {
      final ctrl = MarketplacePager(ref, baseUri);
      return ctrl;
    });
