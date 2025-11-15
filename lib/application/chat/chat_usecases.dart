// File: lib/application/chat/chat_usecases.dart
// Application use-cases to send and fetch chat messages.
import 'package:jaayko/domain/chat/entities/chat_models.dart';
import 'package:jaayko/domain/chat/repositories/chat_repository.dart';

class SendChatMessageUseCase {
  final ChatRepository repo;

  SendChatMessageUseCase(this.repo);

  Future<void> execute({
    required String text,
    required String accountId,
    String? token,
  }) {
    return repo.sendMessage(
      text: text,
      accountId: accountId,
      bearerToken: token,
    );
  }
}

class FetchChatMessagesUseCase {
  final ChatRepository repo;

  FetchChatMessagesUseCase(this.repo);

  Future<ChatPageResult> execute({
    required int page,
    required int limit,
    String? token,
  }) {
    return repo.fetchMessages(page: page, limit: limit, bearerToken: token);
  }
}
