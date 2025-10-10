// File: lib/presentation/features/chatbot/chatbot_page.dart
// Chat UI with access gate and WhatsApp-like ticks for "Moi" messages (based on API state/remoteId).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/shared/formatters.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/domain/chat/entities/chat_models.dart';

class ChatbotPage extends ConsumerStatefulWidget {
  const ChatbotPage({super.key});

  @override
  ConsumerState<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends ConsumerState<ChatbotPage> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
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
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    final grant = ref.watch(accessSessionProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((state.error ?? '').isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
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

    Color _tickColor(ChatDeliveryStatus? s) {
      switch (s) {
        case ChatDeliveryStatus.delivered:
          return Colors.grey; // ✓✓ gris quand remoteId présent
        case ChatDeliveryStatus.processed:
          return Colors.green; // ✓✓ vert quand state=COMPLETED
        case ChatDeliveryStatus.failed:
          return Colors.red; // ✓✓ rouge quand state=FAIL
        case ChatDeliveryStatus.sending:
        default:
          return Colors.grey; // par défaut gris
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("🤖 Assistant financier IA"),
        actions: [
          IconButton(
            tooltip: "Rafraîchir",
            onPressed: state.loading
                ? null
                : () async {
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
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isConnected)
            MaterialBanner(
              content: const Text(
                "Connectez-vous pour enregistrer vos messages et créer des transactions.",
              ),
              leading: const Icon(Icons.lock),
              actions: [
                TextButton(
                  onPressed: () async {
                    final ok = await requireAccess(context, ref);
                    if (!mounted) return;
                    if (ok) {
                      final g = ref.read(accessSessionProvider);
                      if (g?.token != null && g!.token.isNotEmpty) {
                        final ctrl = ref.read(
                          chatbotControllerProvider.notifier,
                        );
                        ctrl.setToken(g.token);
                        await ctrl.refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connecté. Vous pouvez discuter.'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("Se connecter"),
                ),
              ],
            ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(chatbotControllerProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: state.messages.length,
                itemBuilder: (context, i) {
                  final msg = state.messages[i];
                  final isMe = msg.isMe;
                  final bubbleColor = isMe
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceVariant;
                  final textColor = isMe
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant;

                  Widget? _statusIcon() {
                    if (!isMe) return null;
                    if (msg.status == null) return null;
                    // Double coche (done_all) colorée selon statut
                    return Icon(
                      Icons.done_all,
                      size: 16,
                      color: _tickColor(msg.status),
                    );
                  }

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Semantics(
                      label:
                          "${msg.sender} a dit ${msg.text} à ${Formatters.timeHm(msg.createdAt)}",
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (MediaQuery.of(context).size.width * 0.78)
                              .clamp(260, 700),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isMe
                                  ? Radius.zero
                                  : const Radius.circular(16),
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
                                      child: Text(
                                        'IA',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      msg.sender,
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
                                msg.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    Formatters.timeHm(msg.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  if (_statusIcon() != null) ...[
                                    const SizedBox(width: 6),
                                    _statusIcon()!,
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
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
                          hintText: "Écris une dépense (ex: 2000 café)…",
                          border: OutlineInputBorder(),
                          isDense: true,
                          labelText: "Message",
                        ),
                        onSubmitted: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        (ref.read(chatbotControllerProvider).sending ||
                            _ctrl.text.trim().isEmpty)
                        ? null
                        : _send,
                    icon: const Icon(Icons.send),
                    label: Text(
                      ref.watch(chatbotControllerProvider).sending
                          ? "Envoi…"
                          : "Envoyer",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureAccessAndSetToken() async {
    final ok = await requireAccess(context, ref);
    if (!ok) return;
    final g = ref.read(accessSessionProvider);
    if (g?.token != null && g!.token.isNotEmpty) {
      ref.read(chatbotControllerProvider.notifier).setToken(g.token);
    }
  }

  Future<void> _send() async {
    if (ref.read(chatbotControllerProvider).sending) return;
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;

    final grant = ref.read(accessSessionProvider);
    if (grant?.token == null || grant!.token.isEmpty) {
      await _ensureAccessAndSetToken();
      final g2 = ref.read(accessSessionProvider);
      if (g2?.token == null || g2!.token.isEmpty) return;
    }

    await ref.read(chatbotControllerProvider.notifier).send(txt);
    _ctrl.clear();
    setState(() {});
  }
}
