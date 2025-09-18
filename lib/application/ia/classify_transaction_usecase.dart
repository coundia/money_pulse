// Use case: classify a text into a Transaction using AI

import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import '../../domain/ia/ai_service.dart';

class ClassifyTransactionUseCase {
  final AiService ai;

  ClassifyTransactionUseCase(this.ai);

  Future<TransactionEntry> execute(String input) async {
    final result = await ai.classify(input);
    return TransactionEntry(
      amount: result.amount,
      description: result.description,
      id: '',
      typeEntry: '',
      dateTransaction: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
