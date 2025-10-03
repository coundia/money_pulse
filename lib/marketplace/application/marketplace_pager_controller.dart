// Pager with query/company filters, error handling, request de-racing, and
// per-item image index memory. resetAll() truly reloads "all" from the API.

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
  final String? companyId;

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
    this.companyId,
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
      companyId: companyId ?? this.companyId,
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
    statusesCsv: 'PUBLISH', // default public
    companyId: null,
    errorText: null,
    imageIndexByItem: {},
  );
}

class MarketplacePager extends StateNotifier<MarketplacePagerState> {
  final Ref ref;
  final String baseUri;

  // Request sequence to ignore stale responses
  int _reqSeq = 0;

  MarketplacePager(this.ref, this.baseUri)
    : super(MarketplacePagerState.initial()) {
    loadInitial();
  }

  // Convert empty string to null
  String? _nz(String? v) => (v == null || v.trim().isEmpty) ? null : v;

  Future<void> loadInitial() async {
    final mySeq = ++_reqSeq;

    state = state.copyWith(
      isLoading: true,
      page: 0,
      items: [],
      errorText: null,
      imageIndexByItem: {}, // fresh search
      hasNext: true,
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

      if (mySeq != _reqSeq) return;

      state = state.copyWith(
        items: page0.items,
        hasNext: page0.hasNext,
        page: 0,
        isLoading: false,
        errorText: null,
      );
    } catch (e) {
      if (mySeq != _reqSeq) return;
      state = state.copyWith(isLoading: false, errorText: e.toString());
    }
  }

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasNext) return;

    final mySeq = ++_reqSeq;
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
        companyId: state.companyId,
      );

      if (mySeq != _reqSeq) return;

      state = state.copyWith(
        items: [...state.items, ...res.items],
        hasNext: res.hasNext,
        page: nextPage,
        isLoading: false,
      );
    } catch (e) {
      if (mySeq != _reqSeq) return;
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
    String? companyId,
  }) {
    state = state.copyWith(
      query: q != null ? _nz(q) : state.query,
      category: category != null ? _nz(category) : state.category,
      minPrice: minPrice ?? state.minPrice,
      maxPrice: maxPrice ?? state.maxPrice,
      statusesCsv: statusesCsv != null ? _nz(statusesCsv) : state.statusesCsv,
      companyId: companyId != null ? _nz(companyId) : state.companyId,
    );
    loadInitial();
  }

  /// 🔹 Nouvelle API claire pour changer exclusivement le filtre company
  void setCompanyFilter(String? id) {
    state = state.copyWith(companyId: _nz(id));
    loadInitial();
  }

  /// Clear ALL filters back to defaults and reload.
  void resetAll() {
    _reqSeq++; // cancel in-flight
    state = state.copyWith(
      query: null,
      category: null,
      minPrice: null,
      maxPrice: null,
      statusesCsv: 'PUBLISH',
      companyId: null,
      items: [],
      page: 0,
      hasNext: true,
      isLoading: false,
      errorText: null,
      imageIndexByItem: {},
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
      return MarketplacePager(ref, baseUri);
    });
