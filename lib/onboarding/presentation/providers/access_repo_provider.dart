// Riverpod providers wiring for access repository and use cases.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/repositories/access_repository.dart';
import '../../infrastructure/http_access_repository.dart';
import '../../application/request_access_usecase.dart';
import '../../application/verify_access_usecase.dart';

final accessRepoProvider = Provider<AccessRepository>((ref) {
  final client = http.Client();
  final baseUri = Uri.parse(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8095',
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
