// Riverpod state + persistence for HomePage UI preferences (bottom navigation visibility).
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeUiPrefs {
  final bool showBottomNav;

  const HomeUiPrefs({required this.showBottomNav});

  factory HomeUiPrefs.defaults() => const HomeUiPrefs(showBottomNav: false);

  HomeUiPrefs copyWith({bool? showBottomNav}) {
    return HomeUiPrefs(showBottomNav: showBottomNav ?? this.showBottomNav);
  }

  Map<String, dynamic> toMap() => {'showBottomNav': showBottomNav};

  factory HomeUiPrefs.fromMap(Map<String, dynamic> map) {
    return HomeUiPrefs(
      showBottomNav: map['showBottomNav'] is bool
          ? map['showBottomNav'] as bool
          : false,
    );
  }
}

class HomeUiPrefsController extends StateNotifier<HomeUiPrefs> {
  static const _prefsKey = 'home_ui_prefs_v1';

  HomeUiPrefsController() : super(HomeUiPrefs.defaults()) {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = HomeUiPrefs.fromMap(map);
    } catch (_) {}
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(state.toMap()));
  }

  Future<void> reset() async {
    state = HomeUiPrefs.defaults();
    HomeUiPrefs.defaults();
    await _save();
  }

  Future<void> setShowBottomNav(bool v) async {
    state = state.copyWith(showBottomNav: v);
    await _save();
  }
}

final homeUiPrefsProvider =
    StateNotifierProvider<HomeUiPrefsController, HomeUiPrefs>(
      (ref) => HomeUiPrefsController(),
    );
