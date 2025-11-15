// Riverpod notifier for loading and saving quick transactions with fixed kind from parent.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/categories/entities/category.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/domain/customer/entities/customer.dart';
import 'package:jaayko/presentation/app/providers/add_sale_to_debt_usecase_provider.dart';
import 'package:jaayko/presentation/app/providers/checkout_cart_usecase_provider.dart'
    hide checkoutCartUseCaseProvider;
import 'package:jaayko/presentation/app/providers/company_repo_provider.dart';
import 'package:jaayko/presentation/app/providers/customer_repo_provider.dart';
import 'package:jaayko/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:jaayko/presentation/app/account_selection.dart';
import '../../../../domain/company/repositories/company_repository.dart';
import '../../../../domain/customer/repositories/customer_repository.dart';
import '../../../app/providers.dart';
import '../models/tx_item.dart';
import '../widgets/type_selector.dart';
import '../models/tx_item.dart';
import 'tx_quick_add_state.dart';
import 'tx_quick_utils.dart';

final txQuickAddProvider =
    StateNotifierProvider.autoDispose<
      TransactionQuickAddNotifier,
      TxQuickAddState
    >((ref) => TransactionQuickAddNotifier(ref));

class SaveResult {
  final bool ok;
  final String? error;
  const SaveResult(this.ok, [this.error]);
}

class TransactionQuickAddNotifier extends StateNotifier<TxQuickAddState> {
  final Ref ref;
  TransactionQuickAddNotifier(this.ref)
    : super(TxQuickAddState.initial(TxKind.debit));

  Future<void> init({
    required String initialTypeEntry,
    String? initialCustomerId,
    String? initialCompanyId,
  }) async {
    final fixedKind = mapTypeEntryToKind(initialTypeEntry) ?? TxKind.debit;
    state = TxQuickAddState.initial(fixedKind);

    final coRepo = ref.read(companyRepoProvider);
    final cuRepo = ref.read(customerRepoProvider);
    final catRepo = ref.read(categoryRepoProvider);

    List<Company> companies = await coRepo.findAll(
      const CompanyQuery(limit: 300, offset: 0),
    );
    final Company? defaultCo =
        companies.where((e) => e.isDefault == true).isNotEmpty
        ? companies.firstWhere((e) => e.isDefault == true)
        : (companies.isNotEmpty ? companies.first : null);

    String? companyId = initialCompanyId ?? defaultCo?.id;

    Customer? initialCustomer;
    if (initialCustomerId != null && initialCustomerId.isNotEmpty) {
      try {
        initialCustomer = await cuRepo.findById(initialCustomerId);
        companyId = initialCustomer?.companyId ?? companyId;
      } catch (_) {}
    }

    List<Customer> customers = const [];
    if (companyId != null) {
      customers = await cuRepo.findAll(
        CustomerQuery(companyId: companyId, limit: 300, offset: 0),
      );
    } else {
      try {
        customers = await cuRepo.findAll(
          const CustomerQuery(limit: 300, offset: 0),
        );
      } catch (_) {}
    }

    final categories = await catRepo.findAllActive();

    state = state.copyWith(
      companies: companies,
      customers: customers,
      categories: categories,
      companyId: companyId,
      customerId:
          initialCustomer?.id ??
          ((initialCustomerId != null &&
                  customers.any((c) => c.id == initialCustomerId))
              ? initialCustomerId
              : state.customerId),
      setSelectedCategoryNull: true,
    );
  }

  void setCompany(String? id) async {
    state = state.copyWith(
      companyId: id,
      customerId: null,
      customers: const [],
    );
    if (id == null || id.isEmpty) return;
    final cuRepo = ref.read(customerRepoProvider);
    final list = await cuRepo.findAll(
      CustomerQuery(companyId: id, limit: 300, offset: 0),
    );
    state = state.copyWith(customers: list);
  }

  void setCustomer(String? id) {
    state = state.copyWith(customerId: id);
  }

  void setWhen(DateTime dt) {
    state = state.copyWith(when: dt);
  }

  void setItems(List<TxItem> items, {bool lockToItems = true}) {
    state = state.copyWith(items: items, lockAmountToItems: lockToItems);
  }

  void clearItems() {
    state = state.copyWith(items: const [], lockAmountToItems: false);
  }

  void setSelectedCategory(Category? c) {
    state = state.copyWith(
      selectedCategory: c,
      setSelectedCategoryNull: c == null,
    );
  }

  Category? autoSelectCategoryForProducts() {
    final cat = findDefaultCategoryForProducts(state.categories, state.kind);
    if (cat != null) setSelectedCategory(cat);
    return cat;
  }

  List<Category> filterCategories(String query) {
    return filterCategoriesByKind(state.categories, state.kind, query);
  }

  Future<SaveResult> save({
    required int amountCents,
    required String? description,
  }) async {
    try {
      final kind = state.kind;
      final when = state.when;
      final categoryId = state.selectedCategory?.id;
      final companyId = state.companyId;
      final customerId = state.customerId;
      final lines = _buildLines(amountCents, description);

      if (kind == TxKind.debt) {
        if (customerId == null || customerId.isEmpty) {
          return const SaveResult(false, 'Sélectionnez d’abord un client');
        }
        await ref
            .read(addSaleToDebtUseCaseProvider)
            .execute(
              customerId: customerId,
              companyId: companyId,
              categoryId: categoryId,
              description: (description ?? '').trim().isEmpty
                  ? null
                  : description!.trim(),
              when: when,
              lines: lines,
            );
      } else {
        final accountId = ref.read(selectedAccountIdProvider);
        if (accountId == null || accountId.isEmpty) {
          return const SaveResult(false, 'Sélectionnez d’abord un compte');
        }
        final typeEntry = switch (kind) {
          TxKind.debit => 'DEBIT',
          TxKind.credit => 'CREDIT',
          TxKind.remboursement => 'REMBOURSEMENT',
          TxKind.pret => 'PRET',
          TxKind.debt => 'DEBT',
        };
        await ref
            .read(checkoutCartUseCaseProvider)
            .execute(
              typeEntry: typeEntry,
              accountId: accountId,
              categoryId: categoryId,
              description: (description ?? '').trim().isEmpty
                  ? null
                  : description!.trim(),
              companyId: companyId,
              customerId: customerId,
              when: when,
              lines: lines,
            );
      }

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
      ref.invalidate(selectedAccountProvider);

      return const SaveResult(true);
    } catch (e) {
      return SaveResult(false, 'Échec de l’enregistrement: $e');
    }
  }

  List<Map<String, Object?>> _buildLines(int cents, String? description) {
    if (state.items.isNotEmpty) {
      return state.items
          .map<Map<String, Object?>>(
            (it) => {
              'productId': it.productId,
              'label': it.label,
              'quantity': it.quantity,
              'unitPrice': it.unitPriceCents,
            },
          )
          .toList();
    }
    String label;
    switch (state.kind) {
      case TxKind.debit:
        label = 'Dépense';
        break;
      case TxKind.credit:
        label = 'Revenu';
        break;
      case TxKind.debt:
        label = 'Vente à crédit';
        break;
      case TxKind.remboursement:
        label = 'Remboursement';
        break;
      case TxKind.pret:
        label = 'Prêt';
        break;
    }
    return [
      {
        'productId': null,
        'label': (description ?? '').trim().isEmpty
            ? label
            : description!.trim(),
        'quantity': 1,
        'unitPrice': cents,
      },
    ];
  }
}
