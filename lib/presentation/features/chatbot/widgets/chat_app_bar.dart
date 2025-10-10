// File: lib/presentation/features/chatbot/widgets/chat_app_bar.dart
// App bar for chat with refresh action.
import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ChatAppBar({
    super.key,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("🤖 Assistant financier IA"),
      actions: [
        IconButton(
          tooltip: "Rafraîchir",
          onPressed: isLoading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
