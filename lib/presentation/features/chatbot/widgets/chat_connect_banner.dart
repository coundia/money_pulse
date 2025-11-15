// File: lib/presentation/features/chatbot/widgets/chat_connect_banner.dart
// Banner prompting the user to authenticate before chatting.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/onboarding/presentation/providers/access_session_provider.dart';

class ChatConnectBanner extends ConsumerWidget {
  final VoidCallback onConnected;

  const ChatConnectBanner({super.key, required this.onConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialBanner(
      content: const Text(
        "Connectez-vous pour enregistrer vos messages et créer des transactions.",
      ),
      leading: const Icon(Icons.lock),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await requireAccess(context, ref);
            if (!context.mounted) return;
            if (ok) onConnected();
          },
          child: const Text("Se connecter"),
        ),
      ],
    );
  }
}
