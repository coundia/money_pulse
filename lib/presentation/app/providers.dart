import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/infrastructure/repositories/account_repository_sqflite.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/infrastructure/repositories/category_repository_sqflite.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';
import 'package:money_pulse/infrastructure/repositories/transaction_repository_sqflite.dart';
import 'package:money_pulse/application/usecases/ensure_default_account_usecase.dart';
import 'package:money_pulse/application/usecases/seed_default_categories_usecase.dart';
import 'package:money_pulse/application/usecases/quick_add_transaction_usecase.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase.I);

final accountRepoProvider = Provider<AccountRepository>((ref) {
  return AccountRepositorySqflite(ref.read(dbProvider));
});

final categoryRepoProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositorySqflite(ref.read(dbProvider));
});

final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositorySqflite(ref.read(dbProvider));
});

final ensureDefaultAccountUseCaseProvider =
    Provider<EnsureDefaultAccountUseCase>((ref) {
      return EnsureDefaultAccountUseCase(ref.read(accountRepoProvider));
    });

final seedDefaultCategoriesUseCaseProvider =
    Provider<SeedDefaultCategoriesUseCase>((ref) {
      return SeedDefaultCategoriesUseCase(ref.read(categoryRepoProvider));
    });

final quickAddTransactionUseCaseProvider = Provider<QuickAddTransactionUseCase>(
  (ref) {
    return QuickAddTransactionUseCase(
      ref.read(transactionRepoProvider),
      ref.read(accountRepoProvider),
    );
  },
);

class BalanceStateNotifier extends StateNotifier<int> {
  final AccountRepository repo;
  BalanceStateNotifier(this.repo) : super(0);
  Future<void> load() async {
    final a = await repo.findDefault();
    state = a?.balance ?? 0;
  }
}

final balanceProvider = StateNotifierProvider<BalanceStateNotifier, int>((ref) {
  return BalanceStateNotifier(ref.read(accountRepoProvider));
});

class TransactionsStateNotifier extends StateNotifier<List<TransactionEntry>> {
  final TransactionRepository txRepo;
  final AccountRepository accRepo;
  TransactionsStateNotifier(this.txRepo, this.accRepo) : super(const []);
  Future<void> load() async {
    final a = await accRepo.findDefault();
    if (a == null) {
      state = const [];
      return;
    }
    state = await txRepo.findRecentByAccount(a.id, limit: 100);
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsStateNotifier, List<TransactionEntry>>((
      ref,
    ) {
      return TransactionsStateNotifier(
        ref.read(transactionRepoProvider),
        ref.read(accountRepoProvider),
      );
    });

class CategoriesStateNotifier extends StateNotifier<List<Category>> {
  final CategoryRepository repo;
  CategoriesStateNotifier(this.repo) : super(const []);
  Future<void> load() async {
    state = await repo.findAllActive();
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesStateNotifier, List<Category>>((ref) {
      return CategoriesStateNotifier(ref.read(categoryRepoProvider));
    });
