// File: lib/presentation/features/chatbot/chatbot_controller.dart
// State controller for Chat UI: pagination, sending, error handling; ticks come from API state/remoteId.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart';
import 'package:money_pulse/application/chat/chat_usecases.dart';

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

final chatbotControllerProvider =
    StateNotifierProvider<ChatbotController, ChatState>((ref) {
      final fetchUc = ref.watch(fetchChatUseCaseProvider);
      final sendUc = ref.watch(sendChatUseCaseProvider);
      final tokenCtrl = ref.read(chatAuthTokenProvider.notifier);
      final accountCtrl = ref.read(accountIdProvider.notifier);
      return ChatbotController(
        fetchUc: fetchUc,
        sendUc: sendUc,
        token: tokenCtrl,
        accountId: accountCtrl,
      );
    });

class ChatbotController extends StateNotifier<ChatState> {
  final FetchChatMessagesUseCase fetchUc;
  final SendChatMessageUseCase sendUc;
  final StateController<String?> token;
  final StateController<String?> accountId;
  static const _pageSize = 20;

  ChatbotController({
    required this.fetchUc,
    required this.sendUc,
    required this.token,
    required this.accountId,
  }) : super(ChatState.initial());

  void toggleLogs() => state = state.copyWith(showLogs: !state.showLogs);

  ChatMessageEntity _sys(String text) => ChatMessageEntity(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: 'Système',
    text: text,
    createdAt: DateTime.now(),
  );

  Future<void> refresh() async {
    state = state.copyWith(loading: true, page: 0, error: null);
    try {
      final res = await fetchUc.execute(
        page: 0,
        limit: _pageSize,
        token: token.state,
      );

      final merged = [...res.items]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(
        messages: merged,
        loading: false,
        hasMore: res.hasMore,
        page: 0,
      );
    } catch (e) {
      final msg = e.toString();
      final isUnauthorized =
          msg.contains('401') || msg.contains('Unauthorized');
      state = state.copyWith(
        loading: false,
        error: isUnauthorized ? null : msg,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading) return;
    final next = state.page + 1;
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await fetchUc.execute(
        page: next,
        limit: _pageSize,
        token: token.state,
      );
      final merged = [...state.messages, ...res.items]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(
        messages: merged,
        loading: false,
        hasMore: res.hasMore,
        page: next,
      );
    } catch (e) {
      final msg = e.toString();
      final isUnauthorized =
          msg.contains('401') || msg.contains('Unauthorized');
      state = state.copyWith(
        loading: false,
        error: isUnauthorized ? null : msg,
      );
    }
  }

  Future<void> send(String text) async {
    if (state.sending) return;

    final acc = accountId.state;
    if ((acc ?? '').isEmpty) {
      state = state.copyWith(error: 'Compte introuvable');
      return;
    }

    // Ajout optimiste: on affiche "Moi" avec statut sending tout de suite
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

    state = state.copyWith(
      sending: true,
      error: null,
      messages: [...state.messages, temp, ...pre],
    );

    try {
      await sendUc.execute(text: text, accountId: acc!, token: token.state);

      // Après succès HTTP, on passe en "delivered" (✓✓ gris) tant que l’API n’est pas COMPLETED/FAIL
      final updated = state.messages.map((m) {
        if (m.id == temp.id) {
          return m.copyWith(status: ChatDeliveryStatus.delivered);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);

      // Puis on recharge depuis l’API pour refléter COMPLETED/FAIL éventuels
      await refresh();

      if (state.showLogs) {
        state = state.copyWith(
          messages: [...state.messages, _sys('✅ Message envoyé')],
        );
      }
    } catch (e) {
      final postErr = state.showLogs
          ? [_sys('❌ Échec: $e')]
          : const <ChatMessageEntity>[];
      state = state.copyWith(
        sending: false,
        error: e.toString(),
        messages: [...state.messages, ...postErr],
      );
      return;
    }

    state = state.copyWith(sending: false);
  }

  void setToken(String? bearer) {
    token.state = bearer;
  }

  void setAccount(String? id) {
    accountId.state = id;
  }
}
