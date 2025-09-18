// Riverpod pager controller for infinite scrolling.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/marketplace_item.dart';
import '../infrastructure/marketplace_repo_provider.dart';

class MarketplacePagerState {
  final List<MarketplaceItem> items;
  final bool hasNext;
  final int page;
  final bool isLoading;
  final Set<String> saved;

  const MarketplacePagerState({
    required this.items,
    required this.hasNext,
    required this.page,
    required this.isLoading,
    required this.saved,
  });

  MarketplacePagerState copyWith({
    List<MarketplaceItem>? items,
    bool? hasNext,
    int? page,
    bool? isLoading,
    Set<String>? saved,
  }) {
    return MarketplacePagerState(
      items: items ?? this.items,
      hasNext: hasNext ?? this.hasNext,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      saved: saved ?? this.saved,
    );
  }

  static MarketplacePagerState initial() => const MarketplacePagerState(
    items: [],
    hasNext: true,
    page: 0,
    isLoading: false,
    saved: {},
  );
}

class MarketplacePager extends StateNotifier<MarketplacePagerState> {
  final Ref ref;
  final String baseUri;

  MarketplacePager(this.ref, this.baseUri)
    : super(MarketplacePagerState.initial());

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, page: 0, items: []);
    final repo = ref.read(marketplaceRepoProvider(baseUri));
    final page0 = await repo.fetchPage(page: 0);
    state = state.copyWith(
      items: page0.items,
      hasNext: page0.hasNext,
      page: 0,
      isLoading: false,
    );
  }

  Future<void> loadNext() async {
    if (state.isLoading || !state.hasNext) return;
    state = state.copyWith(isLoading: true);
    final repo = ref.read(marketplaceRepoProvider(baseUri));
    final nextPage = state.page + 1;
    final res = await repo.fetchPage(page: nextPage);
    state = state.copyWith(
      items: [...state.items, ...res.items],
      hasNext: res.hasNext,
      page: nextPage,
      isLoading: false,
    );
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
}

final marketplacePagerProvider = StateNotifierProvider.autoDispose
    .family<MarketplacePager, MarketplacePagerState, String>((ref, baseUri) {
      final ctrl = MarketplacePager(ref, baseUri);
      ctrl.loadInitial();
      return ctrl;
    });
