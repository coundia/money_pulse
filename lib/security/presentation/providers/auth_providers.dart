/// Riverpod providers wiring repository, token store, use cases and auth state.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/usecases/login_usecase.dart';
import '../../application/usecases/register_usecase.dart';
import '../../application/usecases/logout_usecase.dart';
import '../../application/usecases/refresh_token_usecase.dart';
import '../../application/usecases/get_current_user_usecase.dart';
import '../../application/usecases/request_password_reset_usecase.dart';
import '../../application/usecases/confirm_password_reset_usecase.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/secure_token_store.dart';
import '../../infrastructure/http/auth_api_client.dart';
import '../../infrastructure/http/auth_http_guard.dart';
import '../../infrastructure/repositories/auth_repository_http.dart';
import '../../infrastructure/storage/secure_token_store_securestorage.dart';

final authBaseUrlProvider = Provider<String>(
  (ref) => 'https://api.example.com',
);

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final base = ref.watch(authBaseUrlProvider);
  return AuthApiClient(baseUrl: base);
});

final tokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStoreSecureStorage();
});

final refreshUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  return RefreshTokenUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});

final authHttpGuardProvider = Provider<AuthHttpGuard>((ref) {
  return AuthHttpGuard(
    tokenStore: ref.watch(tokenStoreProvider),
    refreshUseCase: ref.watch(refreshUseCaseProvider),
    api: ref.watch(authApiClientProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(authApiClientProvider);
  final guard = ref.watch(authHttpGuardProvider);
  return AuthRepositoryHttp(api, guard);
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});

final requestPasswordResetUseCaseProvider =
    Provider<RequestPasswordResetUseCase>((ref) {
      return RequestPasswordResetUseCase(ref.watch(authRepositoryProvider));
    });

final confirmPasswordResetUseCaseProvider =
    Provider<ConfirmPasswordResetUseCase>((ref) {
      return ConfirmPasswordResetUseCase(ref.watch(authRepositoryProvider));
    });

class AuthState {
  final bool isLoading;
  final AuthUser? user;
  final AuthSession? session;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.session,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    AuthUser? user,
    AuthSession? session,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      session: session ?? this.session,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final RefreshTokenUseCase refreshUseCase;
  final GetCurrentUserUseCase meUseCase;
  final SecureTokenStore tokenStore;

  AuthController({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.refreshUseCase,
    required this.meUseCase,
    required this.tokenStore,
  }) : super(const AuthState()) {
    bootstrap();
  }

  Future<void> bootstrap() async {
    state = state.copyWith(isLoading: true, error: null);
    final session = await tokenStore.read();
    if (session == null) {
      state = state.copyWith(isLoading: false, session: null, user: null);
      return;
    }
    try {
      final user = await meUseCase.execute();
      state = state.copyWith(isLoading: false, session: session, user: user);
    } catch (_) {
      state = state.copyWith(isLoading: false, session: null, user: null);
      await tokenStore.clear();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await loginUseCase.execute(
        email: email,
        password: password,
      );
      final user = await meUseCase.execute();
      state = state.copyWith(isLoading: false, session: session, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Échec de connexion');
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final session = await registerUseCase.execute(
        name: name,
        email: email,
        password: password,
      );
      final user = await meUseCase.execute();
      state = state.copyWith(isLoading: false, session: session, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Échec d’inscription');
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await logoutUseCase.execute();
    } finally {
      state = const AuthState(isLoading: false, user: null, session: null);
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      loginUseCase: ref.watch(loginUseCaseProvider),
      registerUseCase: ref.watch(registerUseCaseProvider),
      logoutUseCase: ref.watch(logoutUseCaseProvider),
      refreshUseCase: ref.watch(refreshUseCaseProvider),
      meUseCase: ref.watch(getCurrentUserUseCaseProvider),
      tokenStore: ref.watch(tokenStoreProvider),
    );
  },
);
