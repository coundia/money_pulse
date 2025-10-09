// Helper to trigger token refresh on startup or manual refresh.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/onboarding/presentation/providers/token_refresh_provider.dart';

class HomeRefreshHook {
  static Future<void> onStartup(WidgetRef ref) async {
    try {
      await ref.read(refreshTokenUseCaseProvider).execute();
    } catch (_) {}
  }

  static Future<void> onManualRefresh(WidgetRef ref) async {
    try {
      await ref.read(refreshTokenUseCaseProvider).execute(force: true);
    } catch (_) {}
  }
}
