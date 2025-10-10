// File: lib/presentation/features/chatbot/chatbot_controller.dart
// State controller for Chat UI: pagination, sending, error handling; mounted-safe updates.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart';
import 'package:money_pulse/application/chat/chat_usecases.dart';

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
      final currentToken = token.state; // snapshot before await
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
      final currentToken = token.state; // snapshot before await
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

    // Snapshot BEFORE awaits to avoid touching disposed controllers later
    final acc = accountId.state;
    final currentToken = token.state;

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
      // mark delivered (mounted-safe)
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

  void setToken(String? bearer) {
    // setter mounted-safe
    if (!mounted) return;
    token.state = bearer;
  }

  void setAccount(String? id) {
    if (!mounted) return;
    accountId.state = id;
  }
}
