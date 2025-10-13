// Riverpod providers wiring for the token refresh API and use case.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../shared/constants/env.dart';
import '../../application/refresh_token_usecase.dart';
import '../../infrastructure/token_refresh_api.dart';

final tokenRefreshApiProvider = Provider<TokenRefreshApi>((ref) {
  final client = http.Client();
  final baseUri = Uri.parse(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: Env.BASE_URI,
    ),
  );
  return TokenRefreshApi(client: client, baseUri: baseUri);
});

final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  final api = ref.read(tokenRefreshApiProvider);
  return RefreshTokenUseCase(api, ref);
});
