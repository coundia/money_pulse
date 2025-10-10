// File: lib/presentation/features/chatbot/widgets/chat_message_tile.dart
// Single chat bubble with time and double-tick colored by delivery status.
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/shared/formatters.dart';

class ChatMessageTile extends StatelessWidget {
  final ChatMessageEntity message;
  const ChatMessageTile({super.key, required this.message});

  Color _tickColor(ChatDeliveryStatus? s) {
    switch (s) {
      case ChatDeliveryStatus.delivered:
        return Colors.grey;
      case ChatDeliveryStatus.processed:
        return Colors.green;
      case ChatDeliveryStatus.failed:
        return Colors.red;
      case ChatDeliveryStatus.sending:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isMe
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    Widget? statusIcon() {
      if (!isMe) return null;
      if (message.status == null) return null;
      return Icon(Icons.done_all, size: 16, color: _tickColor(message.status));
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.of(context).size.width * 0.78).clamp(260, 700),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 10,
                      child: Text('IA', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message.sender,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: textColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              if (!isMe) const SizedBox(height: 6),
              Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.25),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    Formatters.timeHm(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  if (statusIcon() != null) ...[
                    const SizedBox(width: 6),
                    statusIcon()!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
