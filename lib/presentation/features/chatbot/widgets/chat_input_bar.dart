// File: lib/presentation/features/chatbot/widgets/chat_input_bar.dart
// Input row with Enter-to-send and send button; mounted-safe after awaits.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const ChatInputBar({super.key, this.scrollController});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) setState(() {}); // update send button enabled state
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureAccessAndSetToken() async {
    final ok = await requireAccess(context, ref);
    if (!mounted || !ok) return;
    final g = ref.read(accessSessionProvider);
    if (g?.token != null && g!.token.isNotEmpty) {
      ref.read(chatbotControllerProvider.notifier).setToken(g.token);
    }
  }

  Future<void> _send() async {
    final controllerState = ref.read(chatbotControllerProvider);
    if (controllerState.sending) return;

    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;

    final grant = ref.read(accessSessionProvider);
    if (grant?.token == null || grant!.token.isEmpty) {
      await _ensureAccessAndSetToken();
      if (!mounted) return;
      final g2 = ref.read(accessSessionProvider);
      if (g2?.token == null || g2!.token.isEmpty) return;
    }

    await ref.read(chatbotControllerProvider.notifier).send(txt);
    if (!mounted) return;

    _ctrl.clear();

    if (widget.scrollController?.hasClients == true) {
      widget.scrollController!.animateTo(
        widget.scrollController!.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(
      chatbotControllerProvider.select((s) => s.sending),
    );
    final hasText = _ctrl.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: RawKeyboardListener(
              focusNode: _focusNode,
              onKey: (event) {
                if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                }
              },
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText:
                      "Écris une dépense (ex: 100 franc pour achat café touba)…",
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: "Message",
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: sending || !hasText ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(sending ? "Envoi…" : "Envoyer"),
          ),
        ],
      ),
    );
  }
}
