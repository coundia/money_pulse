// Riverpod providers wiring for access repository and all access use cases.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../application/register_with_password_usecase.dart';
import '../../application/forgot_password_usecase.dart';
import '../../application/login_with_password_usecase.dart';
import '../../application/reset_password_usecase.dart';
import '../../application/request_access_usecase.dart';
import '../../application/verify_access_usecase.dart';
import '../../domain/repositories/access_repository.dart';
import '../../infrastructure/http_access_repository.dart';

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

final loginWithPasswordUseCaseProvider = Provider<LoginWithPasswordUseCase>((
  ref,
) {
  final repo = ref.read(accessRepoProvider);
  return LoginWithPasswordUseCase(repo);
});

final forgotPasswordUseCaseProvider = Provider<ForgotPasswordUseCase>((ref) {
  final repo = ref.read(accessRepoProvider);
  return ForgotPasswordUseCase(repo);
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  final repo = ref.read(accessRepoProvider);
  return ResetPasswordUseCase(repo);
});

final registerWithPasswordUseCaseProvider =
    Provider<RegisterWithPasswordUseCase>((ref) {
      final repo = ref.read(accessRepoProvider);
      return RegisterWithPasswordUseCase(repo);
    });
