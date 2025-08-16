// Riverpod state + persistence for TransactionSummaryCard preferences, incl. debt/repayment/loan toggles.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SummaryCardPrefs {
  final bool showQuickActions;
  final bool showExpenseButton;
  final bool showIncomeButton;

  // New: entry buttons
  final bool showDebtButton;
  final bool showRepaymentButton;
  final bool showLoanButton;

  final bool showNavShortcuts;
  final bool showNavTransactionsButton;
  final bool showNavPosButton;
  final bool showNavSettingsButton;

  // Extended nav shortcuts
  final bool showNavSearchButton;
  final bool showNavStockButton;
  final bool showNavReportButton;
  final bool showNavProductsButton;
  final bool showNavCustomersButton;
  final bool showNavCategoriesButton;
  final bool showNavAccountsButton;

  final bool showPeriodHeader;
  final bool showMetrics;

  const SummaryCardPrefs({
    required this.showQuickActions,
    required this.showExpenseButton,
    required this.showIncomeButton,
    required this.showDebtButton,
    required this.showRepaymentButton,
    required this.showLoanButton,
    required this.showNavShortcuts,
    required this.showNavTransactionsButton,
    required this.showNavPosButton,
    required this.showNavSettingsButton,
    required this.showNavSearchButton,
    required this.showNavStockButton,
    required this.showNavReportButton,
    required this.showNavProductsButton,
    required this.showNavCustomersButton,
    required this.showNavCategoriesButton,
    required this.showNavAccountsButton,
    required this.showPeriodHeader,
    required this.showMetrics,
  });

  factory SummaryCardPrefs.defaults() => const SummaryCardPrefs(
    showQuickActions: true,
    showExpenseButton: true,
    showIncomeButton: true,
    showDebtButton: false,
    showRepaymentButton: false,
    showLoanButton: false,
    showNavShortcuts: true,
    showNavTransactionsButton: false,
    showNavPosButton: false,
    showNavSettingsButton: false,
    showNavSearchButton: false,
    showNavStockButton: false,
    showNavReportButton: false,
    showNavProductsButton: false,
    showNavCustomersButton: false,
    showNavCategoriesButton: false,
    showNavAccountsButton: false,
    showPeriodHeader: false,
    showMetrics: false,
  );

  SummaryCardPrefs copyWith({
    bool? showQuickActions,
    bool? showExpenseButton,
    bool? showIncomeButton,
    bool? showDebtButton,
    bool? showRepaymentButton,
    bool? showLoanButton,
    bool? showNavShortcuts,
    bool? showNavTransactionsButton,
    bool? showNavPosButton,
    bool? showNavSettingsButton,
    bool? showNavSearchButton,
    bool? showNavStockButton,
    bool? showNavReportButton,
    bool? showNavProductsButton,
    bool? showNavCustomersButton,
    bool? showNavCategoriesButton,
    bool? showNavAccountsButton,
    bool? showPeriodHeader,
    bool? showMetrics,
  }) {
    return SummaryCardPrefs(
      showQuickActions: showQuickActions ?? this.showQuickActions,
      showExpenseButton: showExpenseButton ?? this.showExpenseButton,
      showIncomeButton: showIncomeButton ?? this.showIncomeButton,
      showDebtButton: showDebtButton ?? this.showDebtButton,
      showRepaymentButton: showRepaymentButton ?? this.showRepaymentButton,
      showLoanButton: showLoanButton ?? this.showLoanButton,
      showNavShortcuts: showNavShortcuts ?? this.showNavShortcuts,
      showNavTransactionsButton:
          showNavTransactionsButton ?? this.showNavTransactionsButton,
      showNavPosButton: showNavPosButton ?? this.showNavPosButton,
      showNavSettingsButton:
          showNavSettingsButton ?? this.showNavSettingsButton,
      showNavSearchButton: showNavSearchButton ?? this.showNavSearchButton,
      showNavStockButton: showNavStockButton ?? this.showNavStockButton,
      showNavReportButton: showNavReportButton ?? this.showNavReportButton,
      showNavProductsButton:
          showNavProductsButton ?? this.showNavProductsButton,
      showNavCustomersButton:
          showNavCustomersButton ?? this.showNavCustomersButton,
      showNavCategoriesButton:
          showNavCategoriesButton ?? this.showNavCategoriesButton,
      showNavAccountsButton:
          showNavAccountsButton ?? this.showNavAccountsButton,
      showPeriodHeader: showPeriodHeader ?? this.showPeriodHeader,
      showMetrics: showMetrics ?? this.showMetrics,
    );
  }

  Map<String, dynamic> toMap() => {
    'showQuickActions': showQuickActions,
    'showExpenseButton': showExpenseButton,
    'showIncomeButton': showIncomeButton,
    'showDebtButton': showDebtButton,
    'showRepaymentButton': showRepaymentButton,
    'showLoanButton': showLoanButton,
    'showNavShortcuts': showNavShortcuts,
    'showNavTransactionsButton': showNavTransactionsButton,
    'showNavPosButton': showNavPosButton,
    'showNavSettingsButton': showNavSettingsButton,
    'showNavSearchButton': showNavSearchButton,
    'showNavStockButton': showNavStockButton,
    'showNavReportButton': showNavReportButton,
    'showNavProductsButton': showNavProductsButton,
    'showNavCustomersButton': showNavCustomersButton,
    'showNavCategoriesButton': showNavCategoriesButton,
    'showNavAccountsButton': showNavAccountsButton,
    'showPeriodHeader': showPeriodHeader,
    'showMetrics': showMetrics,
  };

  factory SummaryCardPrefs.fromMap(Map<String, dynamic> map) {
    return SummaryCardPrefs(
      showQuickActions: (map['showQuickActions'] as bool?) ?? true,
      showExpenseButton: (map['showExpenseButton'] as bool?) ?? true,
      showIncomeButton: (map['showIncomeButton'] as bool?) ?? true,
      showDebtButton: (map['showDebtButton'] as bool?) ?? false,
      showRepaymentButton: (map['showRepaymentButton'] as bool?) ?? false,
      showLoanButton: (map['showLoanButton'] as bool?) ?? false,
      showNavShortcuts: (map['showNavShortcuts'] as bool?) ?? true,
      showNavTransactionsButton:
          (map['showNavTransactionsButton'] as bool?) ?? false,
      showNavPosButton: (map['showNavPosButton'] as bool?) ?? true,
      showNavSettingsButton: (map['showNavSettingsButton'] as bool?) ?? false,
      showNavSearchButton: (map['showNavSearchButton'] as bool?) ?? false,
      showNavStockButton: (map['showNavStockButton'] as bool?) ?? false,
      showNavReportButton: (map['showNavReportButton'] as bool?) ?? false,
      showNavProductsButton: (map['showNavProductsButton'] as bool?) ?? false,
      showNavCustomersButton: (map['showNavCustomersButton'] as bool?) ?? false,
      showNavCategoriesButton:
          (map['showNavCategoriesButton'] as bool?) ?? false,
      showNavAccountsButton: (map['showNavAccountsButton'] as bool?) ?? false,
      showPeriodHeader: (map['showPeriodHeader'] as bool?) ?? false,
      showMetrics: (map['showMetrics'] as bool?) ?? false,
    );
  }
}

class SummaryCardPrefsController extends StateNotifier<SummaryCardPrefs> {
  static const _prefsKey = 'summary_card_prefs_v1';

  SummaryCardPrefsController() : super(SummaryCardPrefs.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = SummaryCardPrefs.fromMap(map);
    } catch (_) {}
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(state.toMap()));
  }

  Future<void> reset() async {
    state = SummaryCardPrefs.defaults();
    await _save();
  }

  Future<void> setShowQuickActions(bool v) async {
    state = state.copyWith(showQuickActions: v);
    await _save();
  }

  Future<void> setShowExpenseButton(bool v) async {
    state = state.copyWith(showExpenseButton: v);
    await _save();
  }

  Future<void> setShowIncomeButton(bool v) async {
    state = state.copyWith(showIncomeButton: v);
    await _save();
  }

  Future<void> setShowDebtButton(bool v) async {
    state = state.copyWith(showDebtButton: v);
    await _save();
  }

  Future<void> setShowRepaymentButton(bool v) async {
    state = state.copyWith(showRepaymentButton: v);
    await _save();
  }

  Future<void> setShowLoanButton(bool v) async {
    state = state.copyWith(showLoanButton: v);
    await _save();
  }

  Future<void> setShowNavShortcuts(bool v) async {
    state = state.copyWith(showNavShortcuts: v);
    await _save();
  }

  Future<void> setShowNavTransactionsButton(bool v) async {
    state = state.copyWith(showNavTransactionsButton: v);
    await _save();
  }

  Future<void> setShowNavPosButton(bool v) async {
    state = state.copyWith(showNavPosButton: v);
    await _save();
  }

  Future<void> setShowNavSettingsButton(bool v) async {
    state = state.copyWith(showNavSettingsButton: v);
    await _save();
  }

  Future<void> setShowNavSearchButton(bool v) async {
    state = state.copyWith(showNavSearchButton: v);
    await _save();
  }

  Future<void> setShowNavStockButton(bool v) async {
    state = state.copyWith(showNavStockButton: v);
    await _save();
  }

  Future<void> setShowNavReportButton(bool v) async {
    state = state.copyWith(showNavReportButton: v);
    await _save();
  }

  Future<void> setShowNavProductsButton(bool v) async {
    state = state.copyWith(showNavProductsButton: v);
    await _save();
  }

  Future<void> setShowNavCustomersButton(bool v) async {
    state = state.copyWith(showNavCustomersButton: v);
    await _save();
  }

  Future<void> setShowNavCategoriesButton(bool v) async {
    state = state.copyWith(showNavCategoriesButton: v);
    await _save();
  }

  Future<void> setShowNavAccountsButton(bool v) async {
    state = state.copyWith(showNavAccountsButton: v);
    await _save();
  }

  Future<void> setShowPeriodHeader(bool v) async {
    state = state.copyWith(showPeriodHeader: v);
    await _save();
  }

  Future<void> setShowMetrics(bool v) async {
    state = state.copyWith(showMetrics: v);
    await _save();
  }
}

final summaryCardPrefsProvider =
    StateNotifierProvider<SummaryCardPrefsController, SummaryCardPrefs>(
      (ref) => SummaryCardPrefsController(),
    );
