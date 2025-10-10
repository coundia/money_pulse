// File: lib/presentation/features/chatbot/chat_repo_provider.dart
// Riverpod provider for ChatRepository binding to HTTP implementation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/chat/repositories/chat_repository.dart';
import 'package:money_pulse/infrastructure/chat/chat_repository_http.dart';

final chatBaseUriProvider = Provider<String>((ref) {
  return 'http://127.0.0.1:8095';
});

final chatAuthTokenProvider = StateProvider<String?>((ref) {
  return null;
});

final accountIdProvider = StateProvider<String?>((ref) {
  return '715cc399-ef74-4a53-a324-d505f57855fb';
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final base = ref.watch(chatBaseUriProvider);
  return ChatRepositoryHttp(base);
});
