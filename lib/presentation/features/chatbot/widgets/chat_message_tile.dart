// Single chat bubble with time and double-tick colored by delivery status.
// Long-press opens context actions (Delete / Resend). No three-dots icon.
// Ensures an account is attached before "Resend" on first open.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/shared/formatters.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart'
    hide accountIdProvider;

// ensure a default/selected account exists
import 'package:money_pulse/presentation/app/account_selection.dart'
    show ensureSelectedAccountProvider, selectedAccountIdProvider;

// read current chat account id
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart'
    show accountIdProvider;

class ChatMessageTile extends ConsumerWidget {
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

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset globalPos,
  ) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'resend',
          child: ListTile(
            leading: Icon(Icons.refresh_rounded),
            title: Text('Renvoyer'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Supprimer'),
          ),
        ),
      ],
    );

    if (result == null) return;

    final ctrl = ref.read(chatbotControllerProvider.notifier);

    switch (result) {
      case 'resend':
        HapticFeedback.selectionClick();

        // Auto-attach account if missing (first open scenarios)
        var accId = ref.read(accountIdProvider);
        if ((accId ?? '').isEmpty) {
          await ref.read(ensureSelectedAccountProvider.future);
          accId = ref.read(selectedAccountIdProvider);
          if ((accId ?? '').isNotEmpty) {
            ctrl.setAccountSnapshot(accId);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Aucun compte sélectionné. Sélectionnez un compte puis réessayez.',
                  ),
                ),
              );
            }
            return;
          }
        }

        await ctrl.resendMessage(message.text);
        break;

      case 'delete':
        HapticFeedback.selectionClick();
        final remoteId = message.remoteId ?? message.id; // fallback
        if (remoteId.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de supprimer ce message'),
              ),
            );
          }
          return;
        }
        await ctrl.deleteMessage(remoteId);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message supprimé')));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return GestureDetector(
      onLongPressStart: (d) => _showContextMenu(context, ref, d.globalPosition),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.of(context).size.width * 0.78).clamp(
              260,
              700,
            ),
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
                // Header (avatar + name for IA only)
                if (!isMe) ...[
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
                  const SizedBox(height: 6),
                ],

                // Content
                Text(
                  message.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),

                // Footer: time + status
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
      ),
    );
  }
}
