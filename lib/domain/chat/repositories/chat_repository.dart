// Abstraction for Chat data access and commands.
import '../entities/chat_models.dart';

abstract class ChatRepository {
  Future<void> sendMessage({
    required String text,
    required String accountId,
    String? bearerToken,
  });

  Future<ChatPageResult> fetchMessages({
    required int page,
    required int limit,
    String? bearerToken,
  });

  Future<void> deleteByRemoteId(String remoteId, {String? bearerToken});
}
