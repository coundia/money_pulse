// Riverpod provider wiring CheckoutCartUseCase with AccountRepository and DebtRepository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/domain/accounts/repositories/account_repository.dart';
import 'package:jaayko/presentation/features/debts/debt_repo_provider.dart';
import 'package:jaayko/domain/debts/repositories/debt_repository.dart';
import 'package:jaayko/application/usecases/checkout_cart_usecase.dart';

final checkoutCartUseCaseProvider = Provider<CheckoutCartUseCase>((ref) {
  final db = ref.read(dbProvider);
  final accountRepo = ref.read(accountRepoProvider) as AccountRepository;
  final debtRepo = ref.read(debtRepoProvider) as DebtRepository;
  return CheckoutCartUseCase(db, accountRepo, debtRepo);
});
