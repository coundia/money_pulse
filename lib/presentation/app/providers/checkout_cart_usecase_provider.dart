// checkoutCartUseCaseProvider: exposes CheckoutCartUseCase wired with db and account repository.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

import '../../../application/usecases/checkout_cart_usecase.dart';

final checkoutCartUseCaseProvider = Provider<CheckoutCartUseCase>((ref) {
  final AppDatabase db = ref.read(dbProvider);
  final AccountRepository accRepo = ref.read(accountRepoProvider);
  return CheckoutCartUseCase(db, accRepo);
});
