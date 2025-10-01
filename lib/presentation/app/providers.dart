// App-wide providers and bootstrapping helpers (ensure default account, seed categories, refresh states).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';

import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/infrastructure/repositories/account_repository_sqflite.dart';

import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/infrastructure/repositories/category_repository_sqflite.dart';

import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';
import 'package:money_pulse/infrastructure/repositories/transaction_repository_sqflite.dart';

import 'package:money_pulse/application/usecases/ensure_default_account_usecase.dart';
import 'package:money_pulse/application/usecases/seed_default_categories_usecase.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

// REPORT REPO
import 'package:money_pulse/domain/reports/repositories/report_repository.dart';
import 'package:money_pulse/infrastructure/repositories/report_repository_sqflite.dart';

import '../../application/usecases/checkout_cart_usecase.dart';
import '../../domain/debts/repositories/debt_repository.dart';
import '../../domain/sync/repositories/change_log_repository.dart';
import '../../domain/transactions/repositories/transaction_item_repository.dart';
import '../../infrastructure/sync/change_log_sqlite_repository.dart';
import '../../infrastructure/transactions/repositories/transaction_item_repository_impl.dart';
import '../../onboarding/presentation/providers/access_session_provider.dart';
import '../features/debts/debt_repo_provider.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase.I);

final accountRepoProvider = Provider<AccountRepository>((ref) {
  final appDb = ref.read(dbProvider);

  String? getUserId() {
    final s = ref.read(accessSessionProvider);
    final u = (s?.username ?? '').trim();
    if (u.isNotEmpty) return u; // privilégie le username connecté
    final e = (s?.email ?? '').trim();
    return e.isNotEmpty ? e : null;
  }

  return AccountRepositorySqflite(appDb, getUserId: getUserId);
});

final categoryRepoProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositorySqflite(ref.read(dbProvider));
});

final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositorySqflite(ref.read(dbProvider));
});

// NEW: Report repository provider
final reportRepoProvider = Provider<ReportRepository>((ref) {
  return ReportRepositorySqflite(ref.read(dbProvider));
});

final ensureDefaultAccountUseCaseProvider =
    Provider<EnsureDefaultAccountUseCase>((ref) {
      return EnsureDefaultAccountUseCase(ref.read(accountRepoProvider));
    });

final seedDefaultCategoriesUseCaseProvider =
    Provider<SeedDefaultCategoriesUseCase>((ref) {
      return SeedDefaultCategoriesUseCase(ref.read(categoryRepoProvider));
    });

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

final changeLogRepoProvider = Provider<ChangeLogRepository>((ref) {
  return ChangeLogRepositorySqflite(ref.read(dbProvider));
});

final checkoutCartUseCaseProvider = Provider<CheckoutCartUseCase>((ref) {
  final debtRepo = ref.read(debtRepoProvider) as DebtRepository;
  return CheckoutCartUseCase(
    ref.read(dbProvider),
    ref.read(accountRepoProvider),
    debtRepo,
  );
});

final transactionItemRepoProvider = Provider<TransactionItemRepository>((ref) {
  final db = ref.read(dbProvider);
  return TransactionItemRepositoryImpl(db);
});

/// Bootstrapping post-login: ensure default account, seed categories, then reload ui states.
Future<void> bootstrapAfterLogin(WidgetRef ref) async {
  /*await ref.read(ensureDefaultAccountUseCaseProvider).execute();
  await ref.read(seedDefaultCategoriesUseCaseProvider).execute();

  await Future.wait([
    ref.read(balanceProvider.notifier).load(),
    ref.read(transactionsProvider.notifier).load(),
    ref.read(categoriesProvider.notifier).load(),
  ]);*/
}

/// Optional: a FutureProvider wrapper if you préfèr use in UI.
final postLoginBootstrapProvider = FutureProvider<void>((ref) async {
  await bootstrapAfterLogin(ref as WidgetRef);
});
