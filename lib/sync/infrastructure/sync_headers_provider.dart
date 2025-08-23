/* Providers for building HTTP headers (Authorization, API key, tenant) used by sync.
 * Token is read from accessSessionProvider; falls back to --dart-define if absent.
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';

final syncAuthTokenProvider = Provider<String?>((ref) {
  final grant = ref.watch(accessSessionProvider);
  final tokenFromSession = grant?.token;
  if (tokenFromSession != null && tokenFromSession.isNotEmpty) {
    return tokenFromSession;
  }
  const fromEnv = String.fromEnvironment('SYNC_BEARER', defaultValue: '');
  return fromEnv.isEmpty ? null : fromEnv;
});

final syncApiKeyProvider = Provider<String?>((_) {
  const v = String.fromEnvironment('SYNC_API_KEY', defaultValue: 'system');
  return v.isEmpty ? null : v;
});

final syncTenantNameProvider = Provider<String?>((_) {
  const v = String.fromEnvironment('SYNC_TENANT_NAME', defaultValue: 'system');
  return v.isEmpty ? null : v;
});

typedef HeaderBuilder = Map<String, String> Function();

final syncHeaderBuilderProvider = Provider<HeaderBuilder>((ref) {
  // We return a closure so every HTTP call reads the *current* providers.
  return () {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'accept': '*/*',
    };

    final token = ref.read(syncAuthTokenProvider);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final apiKey = ref.read(syncApiKeyProvider);
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-API-KEY'] = apiKey;
    }

    final tenant = ref.read(syncTenantNameProvider);
    if (tenant != null && tenant.isNotEmpty) {
      headers['X-TENANT-NAME'] = tenant;
    }

    return headers;
  };
});
