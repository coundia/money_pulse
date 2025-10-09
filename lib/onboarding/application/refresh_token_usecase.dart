// Use case to refresh token from the last saved grant; skip if not expiring soon unless forced.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/access_grant.dart';
import '../infrastructure/token_refresh_api.dart';
import '../presentation/providers/access_session_provider.dart';

class RefreshTokenUseCase {
  final TokenRefreshApi api;
  final Ref ref;

  RefreshTokenUseCase(this.api, this.ref);

  Future<AccessGrant?> execute({
    Duration threshold = const Duration(minutes: 15),
    bool force = false,
  }) async {
    final current = ref.read(accessSessionProvider);
    if (current == null) return null;

    if (!force) {
      final iso = current.expiresAt ?? '';
      final exp = DateTime.tryParse(iso);
      if (exp != null) {
        final now = DateTime.now().toUtc();
        final remaining = exp.difference(now);
        if (remaining > threshold) return current;
      }
    }

    final fresh = await api.refresh(current);
    await ref.read(accessSessionProvider.notifier).save(fresh);
    return fresh;
  }
}
