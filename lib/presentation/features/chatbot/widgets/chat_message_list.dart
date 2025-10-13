// Scrollable chat list with empty state and "sending…" tail indicator.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_message_tile.dart';

import '../../accounts/account_page.dart';
import '../../transactions/pages/transaction_list_page.dart';

class ChatMessageList extends ConsumerWidget {
  final ScrollController? controller;
  const ChatMessageList({super.key, this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatbotControllerProvider);
    final items = state.messages;

    if (items.isEmpty) {
      if (state.sending) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Envoi en cours…',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucun message pour le moment',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // Info: compte requis pour discuter
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Astuce : vous devez créer un compte et se connecter pour discuter avec l’IA.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Exemple de message
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Exemple de message :',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                // Bulle d’exemple
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Text(
                      '150 fr pour achat café touba.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // D’autres idées
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: const [
                    _ExampleChip('Vente sac 2500 fr.'),
                    _ExampleChip('Achat riz 19000 fr hier.'),
                  ],
                ),
                const SizedBox(height: 18),

                // Actions rapides
              ],
            ),
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

class _ExampleChip extends StatelessWidget {
  final String text;
  const _ExampleChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(text));
  }
}
