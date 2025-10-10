// File: lib/presentation/features/chatbot/widgets/chat_message_list.dart
// Scrollable chat list with WhatsApp-like message bubbles and ticks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_message_tile.dart';

class ChatMessageList extends ConsumerWidget {
  final ScrollController controller;
  const ChatMessageList({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatbotControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(chatbotControllerProvider.notifier).refresh(),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(12),
        itemCount: state.messages.length,
        itemBuilder: (context, i) {
          final msg = state.messages[i];
          return ChatMessageTile(message: msg);
        },
      ),
    );
  }
}
