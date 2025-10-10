// File: lib/domain/chat/entities/chat_models.dart
// Domain entities for Chat with delivery status and paging based on API state/remoteId.
enum ChatDeliveryStatus { sending, delivered, processed, failed }

class ChatMessageEntity {
  final String id;
  final String sender;
  final String text;
  final DateTime createdAt;
  final bool isMe;
  final ChatDeliveryStatus? status;

  ChatMessageEntity({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.isMe = false,
    this.status,
  });

  ChatMessageEntity copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? createdAt,
    bool? isMe,
    ChatDeliveryStatus? status,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
    );
  }
}

class ChatPageResult {
  final List<ChatMessageEntity> items;
  final int page;
  final int limit;
  final bool hasMore;

  ChatPageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}
