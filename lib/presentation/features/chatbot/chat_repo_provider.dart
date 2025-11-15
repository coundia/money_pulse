// Riverpod providers for ChatRepository (HTTP) and bindings. The accountIdProvider
// initializes and stays synced with the app's default/selected account.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/chat/repositories/chat_repository.dart';
import 'package:jaayko/infrastructure/chat/chat_repository_http.dart';

import 'package:jaayko/presentation/app/providers.dart'
    show selectedAccountProvider;

import '../../../shared/constants/env.dart';
import '../../app/account_selection.dart';

final chatBaseUriProvider = Provider<String>((ref) {
  // TODO: déduire depuis vos prefs/env si nécessaire
  return Env.BASE_URI;
});

/// Jeton d’auth du chatbot (bearer)
final chatAuthTokenProvider = StateProvider<String?>((ref) => null);

/// ID du compte courant pour le chat — calé sur le compte sélectionné de l’app
final accountIdProvider = StateProvider<String?>((ref) {
  final accAsync = ref.watch(selectedAccountProvider);
  final id = accAsync.maybeWhen(data: (a) => a?.id, orElse: () => null);
  return id;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final base = ref.watch(chatBaseUriProvider);
  return ChatRepositoryHttp(base);
});
