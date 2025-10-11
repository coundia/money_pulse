// Bridge provider that keeps chat accountIdProvider in sync with the app's selected default account.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/chatbot/chat_repo_provider.dart';
import 'package:money_pulse/presentation/features/chatbot/chatbot_controller.dart'
    hide accountIdProvider;

import '../../../app/account_selection.dart';

final chatAttachDefaultAccountProvider = Provider<void>((ref) {
  // Whenever the selected account changes (default account in your app),
  // propagate its id into the chat's accountIdProvider and into the controller snapshot.
  ref.listen(selectedAccountProvider, (previous, next) {
    next.whenData((acc) {
      final id = acc?.id;
      if ((id ?? '').isEmpty) return;

      // Met à jour le provider (source unique)
      final stateCtrl = ref.read(accountIdProvider.notifier);
      if (stateCtrl.state != id) {
        stateCtrl.state = id;
      }

      // Met aussi à jour le snapshot interne du contrôleur (pour éviter le null après dispose)
      final ctrl = ref.read(chatbotControllerProvider.notifier);
      ctrl.setAccount(id);
    });
  });
});
