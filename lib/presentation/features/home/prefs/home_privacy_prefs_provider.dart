import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kHideBalanceKey = 'home_hide_balance_v1';

class HomePrivacyPrefs {
  final bool hideBalance;
  const HomePrivacyPrefs({required this.hideBalance});

  HomePrivacyPrefs copyWith({bool? hideBalance}) =>
      HomePrivacyPrefs(hideBalance: hideBalance ?? this.hideBalance);
}

class HomePrivacyPrefsController extends AsyncNotifier<HomePrivacyPrefs> {
  @override
  Future<HomePrivacyPrefs> build() async {
    final prefs = await SharedPreferences.getInstance();
    final hide = prefs.getBool(kHideBalanceKey) ?? false;
    return HomePrivacyPrefs(hideBalance: hide);
  }

  Future<void> toggleHideBalance() async {
    final current = state.value?.hideBalance ?? false;
    final next = !current;
    state = AsyncData(HomePrivacyPrefs(hideBalance: next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHideBalanceKey, next);
  }
}

final homePrivacyPrefsProvider =
    AsyncNotifierProvider<HomePrivacyPrefsController, HomePrivacyPrefs>(
      HomePrivacyPrefsController.new,
    );
