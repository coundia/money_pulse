// File: lib/presentation/features/chatbot/widgets/chat_app_bar.dart
// Reusable chat AppBar with optional leading widget and a refresh action.

import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoading;
  final Future<void> Function()? onRefresh;

  /// Optional leading widget (e.g., a custom BackButton).
  final Widget? leading;

  const ChatAppBar({
    super.key,
    required this.isLoading,
    this.onRefresh,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading, // may be null, AppBar will handle default burger/back
      title: const Text('🤖 Assistant financier IA'),
      actions: [
        IconButton(
          tooltip: 'Rafraîchir',
          onPressed: (isLoading || onRefresh == null)
              ? null
              : () async {
                  await onRefresh!.call();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
