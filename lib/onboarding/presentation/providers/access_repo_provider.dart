// Riverpod providers: repository + use cases wiring.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../onboarding/domain/repositories/access_repository.dart';
import '../../../onboarding/infrastructure/http_access_repository.dart';
import '../../../onboarding/application/request_access_usecase.dart';
import '../../../onboarding/application/verify_access_usecase.dart';

final accessRepoProvider = Provider<AccessRepository>((ref) {
  final client = http.Client();
  final baseUri = Uri.parse(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://example.com',
    ),
  );
  return HttpAccessRepository(client: client, baseUri: baseUri);
});

final requestAccessUseCaseProvider = Provider<RequestAccessUseCase>((ref) {
  final repo = ref.read(accessRepoProvider);
  return RequestAccessUseCase(repo);
});

final verifyAccessUseCaseProvider = Provider<VerifyAccessUseCase>((ref) {
  final repo = ref.read(accessRepoProvider);
  return VerifyAccessUseCase(repo);
});
