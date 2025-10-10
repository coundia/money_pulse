// File: lib/presentation/features/chatbot/pages/chatbot_page.dart
// Screen scaffold that wires app bar, banner, message list and input bar together.
// Uses showApiErrorSnackBar to display clean error messages.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_app_bar.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_connect_banner.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_input_bar.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_message_list.dart';

import '../../../shared/api_error_toast.dart';

class ChatbotPage extends ConsumerStatefulWidget {
  const ChatbotPage({super.key});

  @override
  ConsumerState<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends ConsumerState<ChatbotPage> {
  final _scrollCtrl = ScrollController();
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <=
          _scrollCtrl.position.minScrollExtent + 64) {
        ref.read(chatbotControllerProvider.notifier).loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootstrapped) return;
      _bootstrapped = true;

      await ref.read(accessSessionProvider.notifier).restore();
      final grant = ref.read(accessSessionProvider);
      if (grant?.token != null && grant!.token.isNotEmpty) {
        final ctrl = ref.read(chatbotControllerProvider.notifier);
        ctrl.setToken(grant.token);
        await ctrl.refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    final grant = ref.watch(accessSessionProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use the shared helper to display a clean error toast.
      if ((state.error ?? '').isNotEmpty && mounted) {
        showApiErrorSnackBar(context, state.error!);
      }
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });

    final isConnected = grant?.token.isNotEmpty == true;

    return Scaffold(
      appBar: ChatAppBar(
        isLoading: state.loading,
        onRefresh: () async {
          final ctrl = ref.read(chatbotControllerProvider.notifier);
          if (!isConnected) {
            final ok = await requireAccess(context, ref);
            if (!mounted || !ok) return;
            final g = ref.read(accessSessionProvider);
            if (g?.token != null && g!.token.isNotEmpty) {
              ctrl.setToken(g.token);
            }
          }
          await ctrl.refresh();
        },
      ),
      body: Column(
        children: [
          if (!isConnected)
            ChatConnectBanner(
              onConnected: () async {
                final g = ref.read(accessSessionProvider);
                if (g?.token != null && g!.token.isNotEmpty) {
                  final ctrl = ref.read(chatbotControllerProvider.notifier);
                  ctrl.setToken(g.token);
                  await ctrl.refresh();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connecté. Vous pouvez discuter.'),
                    ),
                  );
                }
              },
            ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: ChatMessageList(controller: _scrollCtrl)),
          const Divider(height: 1),
          SafeArea(child: ChatInputBar(scrollController: _scrollCtrl)),
        ],
      ),
    );
  }
}
