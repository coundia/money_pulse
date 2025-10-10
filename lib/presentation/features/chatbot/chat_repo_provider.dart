// File: lib/presentation/features/chatbot/chat_repo_provider.dart
// Riverpod providers for ChatRepository (HTTP) and bindings. The accountIdProvider
// initializes and stays synced with the app's default/selected account.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/chat/repositories/chat_repository.dart';
import 'package:money_pulse/infrastructure/chat/chat_repository_http.dart';

import 'package:money_pulse/presentation/app/providers.dart'
    show selectedAccountProvider;

import '../../app/account_selection.dart';

final chatBaseUriProvider = Provider<String>((ref) {
  return 'http://127.0.0.1:8095';
});

final chatAuthTokenProvider = StateProvider<String?>((ref) {
  return null;
});

/// Returns the *current* default/selected account id (or null if none).
/// It watches the app's selectedAccountProvider so it stays in sync.
final accountIdProvider = StateProvider<String?>((ref) {
  final accAsync = ref.watch(selectedAccountProvider);
  final id = accAsync.maybeWhen(data: (a) => a?.id, orElse: () => null);
  return id;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final base = ref.watch(chatBaseUriProvider);
  return ChatRepositoryHttp(base);
});
