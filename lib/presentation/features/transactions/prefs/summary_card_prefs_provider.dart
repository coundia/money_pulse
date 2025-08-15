// Riverpod state + persistence for TransactionSummaryCard visibility preferences, including quick actions and nav shortcuts.
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SummaryCardPrefs {
  final bool showQuickActions;
  final bool showExpenseButton;
  final bool showIncomeButton;

  final bool showNavShortcuts;
  final bool showNavTransactionsButton;
  final bool showNavPosButton;
  final bool showNavSettingsButton;

  final bool showPeriodHeader;
  final bool showMetrics;

  const SummaryCardPrefs({
    required this.showQuickActions,
    required this.showExpenseButton,
    required this.showIncomeButton,
    required this.showNavShortcuts,
    required this.showNavTransactionsButton,
    required this.showNavPosButton,
    required this.showNavSettingsButton,
    required this.showPeriodHeader,
    required this.showMetrics,
  });

  factory SummaryCardPrefs.defaults() => const SummaryCardPrefs(
    showQuickActions: true,
    showExpenseButton: true,
    showIncomeButton: true,
    showNavShortcuts: true,
    showNavTransactionsButton: true,
    showNavPosButton: true,
    showNavSettingsButton: true,
    showPeriodHeader: true,
    showMetrics: true,
  );

  SummaryCardPrefs copyWith({
    bool? showQuickActions,
    bool? showExpenseButton,
    bool? showIncomeButton,
    bool? showNavShortcuts,
    bool? showNavTransactionsButton,
    bool? showNavPosButton,
    bool? showNavSettingsButton,
    bool? showPeriodHeader,
    bool? showMetrics,
  }) {
    return SummaryCardPrefs(
      showQuickActions: showQuickActions ?? this.showQuickActions,
      showExpenseButton: showExpenseButton ?? this.showExpenseButton,
      showIncomeButton: showIncomeButton ?? this.showIncomeButton,
      showNavShortcuts: showNavShortcuts ?? this.showNavShortcuts,
      showNavTransactionsButton:
          showNavTransactionsButton ?? this.showNavTransactionsButton,
      showNavPosButton: showNavPosButton ?? this.showNavPosButton,
      showNavSettingsButton:
          showNavSettingsButton ?? this.showNavSettingsButton,
      showPeriodHeader: showPeriodHeader ?? this.showPeriodHeader,
      showMetrics: showMetrics ?? this.showMetrics,
    );
  }

  Map<String, dynamic> toMap() => {
    'showQuickActions': showQuickActions,
    'showExpenseButton': showExpenseButton,
    'showIncomeButton': showIncomeButton,
    'showNavShortcuts': showNavShortcuts,
    'showNavTransactionsButton': showNavTransactionsButton,
    'showNavPosButton': showNavPosButton,
    'showNavSettingsButton': showNavSettingsButton,
    'showPeriodHeader': showPeriodHeader,
    'showMetrics': showMetrics,
  };

  factory SummaryCardPrefs.fromMap(Map<String, dynamic> map) {
    return SummaryCardPrefs(
      showQuickActions: map['showQuickActions'] is bool
          ? map['showQuickActions'] as bool
          : true,
      showExpenseButton: map['showExpenseButton'] is bool
          ? map['showExpenseButton'] as bool
          : true,
      showIncomeButton: map['showIncomeButton'] is bool
          ? map['showIncomeButton'] as bool
          : true,
      showNavShortcuts: map['showNavShortcuts'] is bool
          ? map['showNavShortcuts'] as bool
          : true,
      showNavTransactionsButton: map['showNavTransactionsButton'] is bool
          ? map['showNavTransactionsButton'] as bool
          : true,
      showNavPosButton: map['showNavPosButton'] is bool
          ? map['showNavPosButton'] as bool
          : true,
      showNavSettingsButton: map['showNavSettingsButton'] is bool
          ? map['showNavSettingsButton'] as bool
          : true,
      showPeriodHeader: map['showPeriodHeader'] is bool
          ? map['showPeriodHeader'] as bool
          : true,
      showMetrics: map['showMetrics'] is bool
          ? map['showMetrics'] as bool
          : true,
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
