/// Riverpod provider for the app settings repository.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/settings/repositories/app_settings_repository.dart';
import 'package:money_pulse/infrastructure/settings/app_settings_repository_prefs.dart';

final appSettingsRepoProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepositoryPrefs();
});
