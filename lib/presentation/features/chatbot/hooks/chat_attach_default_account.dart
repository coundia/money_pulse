// Bridge provider that keeps chat accountIdProvider in sync with the app's selected default account.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/features/chatbot/chat_repo_provider.dart';
import 'package:jaayko/presentation/features/chatbot/chatbot_controller.dart'
    hide accountIdProvider;

import '../../../app/account_selection.dart';

final chatAttachDefaultAccountProvider = Provider<void>((ref) {
  ref.listen(selectedAccountProvider, (previous, next) {
    next.whenData((acc) {
      final id = acc?.id;
      if ((id ?? '').isEmpty) return;

      // MAJ le StateProvider (si vivant)
      final stateCtrl = ref.read(accountIdProvider.notifier);
      if (stateCtrl.state != id) {
        stateCtrl.state = id;
      }

      // MAJ le snapshot interne du contrôleur (ne crash pas si disposé)
      final ctrl = ref.read(chatbotControllerProvider.notifier);
      ctrl.setAccountSnapshot(id);
    });
  });
});
