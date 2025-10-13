/// SharedPreferences-based implementation for app settings.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_pulse/domain/settings/entities/app_settings.dart';
import 'package:money_pulse/domain/settings/repositories/app_settings_repository.dart';

class AppSettingsRepositoryPrefs implements AppSettingsRepository {
  static const _kAutoRefresh = 'settings.autoRefreshOnFocus';

  @override
  Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final autoRefresh = sp.getBool(_kAutoRefresh);
    return AppSettings(
      autoRefreshOnFocus:
          autoRefresh ?? AppSettings.defaults.autoRefreshOnFocus,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAutoRefresh, settings.autoRefreshOnFocus);
  }
}
