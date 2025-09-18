import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/ia/classify_transaction_usecase.dart';
import '../../../infrastructure/ia/ai_service_http.dart';

class ChatMessage {
  final String sender;
  final String text;
  ChatMessage(this.sender, this.text);
}

final chatbotProvider =
    StateNotifierProvider<ChatbotNotifier, List<ChatMessage>>((ref) {
      final usecase = ref.read(classifyTransactionUseCaseProvider);
      return ChatbotNotifier(usecase);
    });

class ChatbotNotifier extends StateNotifier<List<ChatMessage>> {
  final ClassifyTransactionUseCase usecase;

  ChatbotNotifier(this.usecase) : super([]);

  Future<void> sendMessage(String input) async {
    state = [...state, ChatMessage("Moi", input)];
    try {
      final tx = await usecase.execute(input);
      final reply =
          "✅ Ajouté : ${tx.typeEntry} de ${tx.amount} FCFA dans ${tx.categoryId} (${tx.description}).";
      state = [...state, ChatMessage("IA", reply)];
    } catch (e) {
      state = [...state, ChatMessage("IA", "⚠️ Erreur: $e")];
    }
  }
}

final classifyTransactionUseCaseProvider = Provider<ClassifyTransactionUseCase>(
  (ref) {
    final ai = ref.read(aiServiceProvider);
    return ClassifyTransactionUseCase(ai);
  },
);

final aiServiceProvider = Provider((ref) {
  return AiServiceHttp("https://www.pcoundia.com/ia");
});
