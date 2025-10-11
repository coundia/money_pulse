// File: lib/presentation/features/chatbot/chatbot_controller.dart
// State controller for Chat UI: pagination, sending, error handling; mounted-safe updates.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart';
import 'package:money_pulse/application/chat/chat_usecases.dart';

import '../../../domain/chat/repositories/chat_repository.dart';
import '../../../shared/api_error_toast.dart';

class ChatState {
  final List<ChatMessageEntity> messages;
  final bool loading;
  final bool sending;
  final bool hasMore;
  final int page;
  final String? error;
  final bool showLogs;

  ChatState({
    required this.messages,
    required this.loading,
    required this.sending,
    required this.hasMore,
    required this.page,
    required this.showLogs,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessageEntity>? messages,
    bool? loading,
    bool? sending,
    bool? hasMore,
    int? page,
    String? error,
    bool? showLogs,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      showLogs: showLogs ?? this.showLogs,
      error: error,
    );
  }

  factory ChatState.initial() => ChatState(
    messages: const [],
    loading: false,
    sending: false,
    hasMore: true,
    page: 0,
    showLogs: false,
  );
}

final fetchChatUseCaseProvider = Provider<FetchChatMessagesUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return FetchChatMessagesUseCase(repo);
});

final sendChatUseCaseProvider = Provider<SendChatMessageUseCase>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return SendChatMessageUseCase(repo);
});

/// Snapshots externes (token / account) — restent inchangés si le scope est disposé.
final chatAuthTokenProvider = StateProvider<String?>((_) => null);
final accountIdProvider = StateProvider<String?>((_) => null);

final chatbotControllerProvider =
    StateNotifierProvider<ChatbotController, ChatState>((ref) {
      final fetchUc = ref.watch(fetchChatUseCaseProvider);
      final sendUc = ref.watch(sendChatUseCaseProvider);
      final tokenCtrl = ref.read(chatAuthTokenProvider.notifier);
      final accountCtrl = ref.read(accountIdProvider.notifier);
      final repo = ref.read(chatRepositoryProvider); // <-- pour delete
      return ChatbotController(
        fetchUc: fetchUc,
        sendUc: sendUc,
        token: tokenCtrl,
        accountId: accountCtrl,
        repo: repo,
      );
    });

class ChatbotController extends StateNotifier<ChatState> {
  final FetchChatMessagesUseCase fetchUc;
  final SendChatMessageUseCase sendUc;

  /// Accès direct au repo (pour deleteByRemoteId).
  final ChatRepository repo;

  /// Riverpod state holders (peuvent être disposés par le scope).
  final StateController<String?> token;
  final StateController<String?> accountId;

  /// Snapshots internes pour éviter de toucher les StateController
  /// après dispose (ex: on quitte la page pendant un envoi).
  String? _tokenSnapshot;
  String? _accountSnapshot;

  static const _pageSize = 20;

  ChatbotController({
    required this.fetchUc,
    required this.sendUc,
    required this.token,
    required this.accountId,
    required this.repo,
  }) : super(ChatState.initial()) {
    _tokenSnapshot = token.state;
    _accountSnapshot = accountId.state;
  }

  // Mounted-safe setter
  void _set(ChatState next) {
    if (!mounted) return;
    state = next;
  }

  void toggleLogs() => _set(state.copyWith(showLogs: !state.showLogs));

  ChatMessageEntity _sys(String text) => ChatMessageEntity(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: 'Système',
    text: text,
    createdAt: DateTime.now(),
  );

  Future<void> refresh() async {
    _set(state.copyWith(loading: true, page: 0, error: null));
    try {
      final currentToken = _tokenSnapshot;
      final res = await fetchUc.execute(
        page: 0,
        limit: _pageSize,
        token: currentToken,
      );
      final merged = [...res.items]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _set(
        state.copyWith(
          messages: merged,
          loading: false,
          hasMore: res.hasMore,
          page: 0,
        ),
      );
    } catch (e) {
      final friendly = extractHumanError(e);
      final raw = e.toString();
      final isUnauthorized =
          raw.contains('401') || raw.contains('Unauthorized');
      _set(
        state.copyWith(loading: false, error: isUnauthorized ? null : friendly),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading) return;
    final next = state.page + 1;
    _set(state.copyWith(loading: true, error: null));
    try {
      final currentToken = _tokenSnapshot;
      final res = await fetchUc.execute(
        page: next,
        limit: _pageSize,
        token: currentToken,
      );
      final merged = [...state.messages, ...res.items]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _set(
        state.copyWith(
          messages: merged,
          loading: false,
          hasMore: res.hasMore,
          page: next,
        ),
      );
    } catch (e) {
      final friendly = extractHumanError(e);
      final raw = e.toString();
      final isUnauthorized =
          raw.contains('401') || raw.contains('Unauthorized');
      _set(
        state.copyWith(loading: false, error: isUnauthorized ? null : friendly),
      );
    }
  }

  Future<void> send(String text) async {
    if (state.sending) return;

    // Snapshots locaux : NE PAS toucher aux StateController ici
    final acc = _accountSnapshot;
    final currentToken = _tokenSnapshot;

    if ((acc ?? '').isEmpty) {
      _set(state.copyWith(error: 'Compte introuvable'));
      return;
    }

    final temp = ChatMessageEntity(
      id: 'local-${const Uuid().v4()}',
      sender: 'Moi',
      text: text,
      createdAt: DateTime.now(),
      isMe: true,
      status: ChatDeliveryStatus.sending,
    );

    final pre = <ChatMessageEntity>[];
    if (state.showLogs) pre.add(_sys('↗️ POST /api/v1/commands/chat …'));

    _set(
      state.copyWith(
        sending: true,
        error: null,
        messages: [...state.messages, temp, ...pre],
      ),
    );

    try {
      await sendUc.execute(text: text, accountId: acc!, token: currentToken);
      // mark delivered
      final updated = state.messages.map((m) {
        if (m.id == temp.id) {
          return m.copyWith(status: ChatDeliveryStatus.delivered);
        }
        return m;
      }).toList();
      _set(state.copyWith(messages: updated));

      await refresh();

      if (state.showLogs) {
        _set(
          state.copyWith(
            messages: [...state.messages, _sys('✅ Message envoyé')],
          ),
        );
      }
    } catch (e) {
      final friendly = extractHumanError(e);
      final postErr = state.showLogs
          ? [_sys('❌ Échec: $friendly')]
          : const <ChatMessageEntity>[];
      _set(
        state.copyWith(
          sending: false,
          error: friendly,
          messages: [...state.messages, ...postErr],
        ),
      );
      return;
    }

    _set(state.copyWith(sending: false));
  }

  /// Met à jour la valeur Riverpod ET le snapshot local.
  void setToken(String? bearer) {
    if (!mounted) return;
    token.state = bearer;
    _tokenSnapshot = bearer;
  }

  /// Variante snapshot-only (utile depuis des scopes éphémères).
  void setTokenSnapshot(String? bearer) {
    _tokenSnapshot = bearer;
  }

  /// Met à jour la valeur Riverpod ET le snapshot local.
  void setAccount(String? id) {
    if (!mounted) return;
    accountId.state = id;
    _accountSnapshot = id;
  }

  /// Variante snapshot-only (utile depuis des scopes éphémères).
  void setAccountSnapshot(String? id) {
    _accountSnapshot = id;
  }

  // ----------------------
  // Actions de menu
  // ----------------------

  /// Supprime un message côté API par son `remoteId`, puis rafraîchit la liste.
  Future<void> deleteMessage(String remoteId) async {
    try {
      await repo.deleteByRemoteId(remoteId, bearerToken: _tokenSnapshot);
      await refresh();
    } catch (e) {
      _set(state.copyWith(error: extractHumanError(e)));
    }
  }

  /// Renvoyer un message (réutilise send()).
  Future<void> resendMessage(String text) => send(text);
}
