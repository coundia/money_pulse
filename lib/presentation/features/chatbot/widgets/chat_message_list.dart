// Scrollable chat list with empty state and "sending…" tail indicator.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_message_tile.dart';

class ChatMessageList extends ConsumerWidget {
  final ScrollController? controller;
  const ChatMessageList({super.key, this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatbotControllerProvider);
    final items = state.messages;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            state.sending ? 'Envoi en cours…' : 'Aucun message pour le moment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    // Taille = messages + (1 item de pied si "sending")
    final count = items.length + (state.sending ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: count,
      itemBuilder: (context, index) {
        // Item "sending…" ajouté tout en bas
        final isSendingTail = state.sending && index == count - 1;
        if (isSendingTail) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Envoi en cours…'),
              ],
            ),
          );
        }

        final msg = items[index];
        return ChatMessageTile(message: msg);
      },
    );
  }
}
