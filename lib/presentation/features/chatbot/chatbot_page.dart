// File: lib/presentation/features/chatbot/pages/chatbot_page.dart
// Screen scaffold that wires app bar, banner, message list and input bar together.
// Uses the reusable ServerUnavailable.showSnackBar for clear user messaging on server failures,
// and attaches default accountId safely (snapshot-based).
// When leaving this page (system back or app bar back), we mark the RefocusBus with 'chatbot'
// and pop with a "refresh" result so the caller can optionally auto-refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_app_bar.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_connect_banner.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_input_bar.dart';
import 'package:money_pulse/presentation/features/chatbot/widgets/chat_message_list.dart';
import 'package:money_pulse/presentation/features/chatbot/hooks/chat_attach_default_account.dart';

// ensure selected account default
import 'package:money_pulse/presentation/app/account_selection.dart'
    show ensureSelectedAccountProvider, selectedAccountIdProvider;

import 'package:money_pulse/presentation/navigation/refocus_bus.dart';
import 'package:money_pulse/shared/server_unavailable.dart';

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

    // Bootstrap after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_bootstrapped) return;
      _bootstrapped = true;

      // 1) Restore session
      await ref.read(accessSessionProvider.notifier).restore();

      // 2) Ensure a selected/default account exists and attach its id to the controller (snapshot-safe)
      await ref.read(ensureSelectedAccountProvider.future);
      final accId = ref.read(selectedAccountIdProvider);
      if ((accId ?? '').isNotEmpty) {
        ref.read(chatbotControllerProvider.notifier).setAccountSnapshot(accId);
      }

      // 3) If a token exists, set it snapshot-safe and load messages
      final grant = ref.read(accessSessionProvider);
      if (grant?.token != null && grant!.token.isNotEmpty) {
        final ctrl = ref.read(chatbotControllerProvider.notifier);
        ctrl.setTokenSnapshot(grant.token);
        try {
          await ctrl.refresh();
        } catch (e, st) {
          if (!mounted) return;
          ServerUnavailable.showSnackBar(
            context,
            e,
            stackTrace: st,
            where: 'ChatbotPage.bootstrap.refresh',
            actionLabel: 'Réessayer',
            onAction: () async {
              try {
                await ctrl.refresh();
              } catch (e2, st2) {
                ServerUnavailable.showSnackBar(
                  context,
                  e2,
                  stackTrace: st2,
                  where: 'ChatbotPage.bootstrap.refresh.retry',
                );
              }
            },
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Pop with a "refresh" result so the previous page can reload,
  /// and mark that we are coming back from the chatbot.
  Future<bool> _onWillPop() async {
    if (!mounted) return true;
    RefocusBus.mark('chatbot');
    Navigator.of(context).pop('refresh');
    return false; // we handled the pop ourselves
  }

  @override
  Widget build(BuildContext context) {
    // Keep chat accountId synced with default selected account while page is alive
    ref.watch(chatAttachDefaultAccountProvider);

    final state = ref.watch(chatbotControllerProvider);
    final grant = ref.watch(accessSessionProvider);

    // Post-frame UI effects (autoscroll; error toast via reusable server-unavailable)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Display a generic "server unavailable" message if controller surfaces a friendly error
      if ((state.error ?? '').isNotEmpty) {
        ServerUnavailable.showSnackBar(
          context,
          state.error!,
          where: 'ChatbotPage.frame.error',
          actionLabel: 'Réessayer',
          onAction: () async {
            try {
              await ref.read(chatbotControllerProvider.notifier).refresh();
            } catch (e2, st2) {
              ServerUnavailable.showSnackBar(
                context,
                e2,
                stackTrace: st2,
                where: 'ChatbotPage.frame.error.retry',
              );
            }
          },
        );
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: ChatAppBar(
          isLoading: state.loading,
          // Back button from AppBar will pop; WillPopScope converts to pop('refresh') and marks bus.
          onRefresh: () async {
            final ctrl = ref.read(chatbotControllerProvider.notifier);
            if (!isConnected) {
              final ok = await requireAccess(context, ref);
              if (!mounted || !ok) return;
              final g = ref.read(accessSessionProvider);
              if (g?.token != null && g!.token.isNotEmpty) {
                ctrl.setTokenSnapshot(g.token); // snapshot-safe
              }
            }
            try {
              await ctrl.refresh();
            } catch (e, st) {
              if (!mounted) return;
              ServerUnavailable.showSnackBar(
                context,
                e,
                stackTrace: st,
                where: 'ChatbotPage.appbar.refresh',
                actionLabel: 'Réessayer',
                onAction: () async {
                  try {
                    await ctrl.refresh();
                  } catch (e2, st2) {
                    ServerUnavailable.showSnackBar(
                      context,
                      e2,
                      stackTrace: st2,
                      where: 'ChatbotPage.appbar.refresh.retry',
                    );
                  }
                },
              );
            }
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
                    ctrl.setTokenSnapshot(g.token); // snapshot-safe
                    try {
                      await ctrl.refresh();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connecté. Vous pouvez discuter.'),
                        ),
                      );
                    } catch (e, st) {
                      if (!mounted) return;
                      ServerUnavailable.showSnackBar(
                        context,
                        e,
                        stackTrace: st,
                        where: 'ChatbotPage.connectBanner.refresh',
                        actionLabel: 'Réessayer',
                        onAction: () async {
                          try {
                            await ctrl.refresh();
                          } catch (e2, st2) {
                            ServerUnavailable.showSnackBar(
                              context,
                              e2,
                              stackTrace: st2,
                              where: 'ChatbotPage.connectBanner.refresh.retry',
                            );
                          }
                        },
                      );
                    }
                  }
                },
              ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: ChatMessageList(controller: _scrollCtrl)),
            const Divider(height: 1),
            SafeArea(child: ChatInputBar(scrollController: _scrollCtrl)),
          ],
        ),
      ),
    );
  }
}
