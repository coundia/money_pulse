/* Provides the API base URI for remote sync; override in ProviderScope as needed. */
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default points to local dev server. You can override it at app startup:
/// ProviderScope(overrides: [ baseUriProvider.overrideWithValue('https://api.example.com') ], child: App())
final baseUriProvider = Provider<String>((ref) {
  const fromEnv = String.fromEnvironment(
    'API_BASE_URI',
    defaultValue: 'http://127.0.0.1:8095',
  );
  return fromEnv;
});
