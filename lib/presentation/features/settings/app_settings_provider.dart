/// Riverpod state and notifiers for app settings.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/settings/entities/app_settings.dart';
import 'package:jaayko/presentation/app/providers/app_settings_repo_provider.dart';

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = ref.read(appSettingsRepoProvider);
    final loaded = await repo.load();
    return loaded;
  }

  Future<void> setAutoRefreshOnFocus(bool value) async {
    final current = state.value ?? AppSettings.defaults;
    final updated = current.copyWith(autoRefreshOnFocus: value);
    state = AsyncData(updated);
    final repo = ref.read(appSettingsRepoProvider);
    await repo.save(updated);
  }
}

final autoRefreshOnFocusEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.autoRefreshOnFocus;
});
