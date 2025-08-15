// Riverpod provider for AddSaleToDebtUseCase.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';
import 'package:money_pulse/presentation/features/debts/debt_repo_provider.dart';
import 'package:money_pulse/application/usecases/add_sale_to_debt_usecase.dart';

final addSaleToDebtUseCaseProvider = Provider<AddSaleToDebtUseCase>((ref) {
  final db = ref.read(dbProvider);
  final repo = ref.read(debtRepoProvider) as DebtRepository;
  return AddSaleToDebtUseCase(db, repo);
});
