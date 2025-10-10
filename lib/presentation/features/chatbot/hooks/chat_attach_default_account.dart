// File: lib/presentation/features/chatbot/hooks/chat_attach_default_account.dart
// Bridge provider that keeps chat accountIdProvider in sync with the app's selected default account.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart';

import '../../../app/account_selection.dart';

final chatAttachDefaultAccountProvider = Provider<void>((ref) {
  // Whenever the selected account changes (default account in your app),
  // propagate its id into the chat's accountIdProvider.
  ref.listen(selectedAccountProvider, (previous, next) {
    next.whenData((acc) {
      final id = acc?.id;
      if ((id ?? '').isEmpty) return;
      final ctrl = ref.read(accountIdProvider.notifier);
      if (ctrl.state != id) {
        ctrl.state = id;
      }
    });
  });
});
