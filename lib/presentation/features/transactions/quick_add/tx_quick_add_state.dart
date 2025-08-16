import 'package:equatable/equatable.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';

import '../models/tx_item.dart';
import '../widgets/type_selector.dart';

class TxQuickAddState extends Equatable {
  final TxKind kind;
  final DateTime when;
  final String? companyId;
  final String? customerId;
  final List<Company> companies;
  final List<Customer> customers;
  final List<Category> categories;
  final Category? selectedCategory;
  final List<TxItem> items;
  final bool lockAmountToItems;
  final bool busy;

  const TxQuickAddState({
    required this.kind,
    required this.when,
    required this.companyId,
    required this.customerId,
    required this.companies,
    required this.customers,
    required this.categories,
    required this.selectedCategory,
    required this.items,
    required this.lockAmountToItems,
    required this.busy,
  });

  factory TxQuickAddState.initial(TxKind kind) => TxQuickAddState(
    kind: kind,
    when: DateTime.now(),
    companyId: null,
    customerId: null,
    companies: const [],
    customers: const [],
    categories: const [],
    selectedCategory: null,
    items: const [],
    lockAmountToItems: true,
    busy: false,
  );

  TxQuickAddState copyWith({
    TxKind? kind,
    DateTime? when,
    String? companyId,
    String? customerId,
    List<Company>? companies,
    List<Customer>? customers,
    List<Category>? categories,
    Category? selectedCategory,
    bool setSelectedCategoryNull = false,
    List<TxItem>? items,
    bool? lockAmountToItems,
    bool? busy,
  }) {
    return TxQuickAddState(
      kind: kind ?? this.kind,
      when: when ?? this.when,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      companies: companies ?? this.companies,
      customers: customers ?? this.customers,
      categories: categories ?? this.categories,
      selectedCategory: setSelectedCategoryNull
          ? null
          : (selectedCategory ?? this.selectedCategory),
      items: items ?? this.items,
      lockAmountToItems: lockAmountToItems ?? this.lockAmountToItems,
      busy: busy ?? this.busy,
    );
  }

  @override
  List<Object?> get props => [
    kind,
    when,
    companyId,
    customerId,
    companies,
    customers,
    categories,
    selectedCategory,
    items,
    lockAmountToItems,
    busy,
  ];
}
