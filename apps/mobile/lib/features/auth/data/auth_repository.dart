import 'auth_api_client.dart';
import 'auth_models.dart';
import 'auth_token_store.dart';

abstract interface class AuthRepository {
  Future<AuthUser?> restoreSession();

  Future<AuthUser> login({
    required String email,
    required String password,
    required bool remember,
  });

  Future<AuthUser> register({
    required String displayName,
    required String studentId,
    required String email,
    required String password,
  });

  Future<void> logout();
}

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({AuthApiClient? api, AuthTokenStore? tokenStore})
      : _api = api ?? AuthApiClient(),
        _tokenStore = tokenStore ?? AuthTokenStore();

  final AuthApiClient _api;
  final AuthTokenStore _tokenStore;
  AuthTokens? _tokens;

  @override
  Future<AuthUser?> restoreSession() async {
    final storedTokens = await _tokenStore.read();
    if (storedTokens == null) return null;
    _tokens = storedTokens;
    try {
      return await _api.me(storedTokens.accessToken);
    } on AuthApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      try {
        final refreshed = await _api.refresh(storedTokens.refreshToken);
        _tokens = refreshed;
        await _tokenStore.write(refreshed);
        return await _api.me(refreshed.accessToken);
      } on AuthApiException {
        await _clearTokens();
        return null;
      }
    }
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final session = await _api.login(email: email, password: password);
    _tokens = session.tokens;
    if (remember) {
      await _tokenStore.write(session.tokens);
    } else {
      await _tokenStore.clear();
    }
    return session.user;
  }

  @override
  Future<AuthUser> register({
    required String displayName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final session = await _api.register(
      displayName: displayName,
      studentId: studentId,
      email: email,
      password: password,
    );
    _tokens = session.tokens;
    await _tokenStore.write(session.tokens);
    return session.user;
  }

  @override
  Future<void> logout() async {
    final accessToken = _tokens?.accessToken;
    try {
      if (accessToken != null) await _api.logout(accessToken);
    } finally {
      await _clearTokens();
    }
  }

  Future<void> _clearTokens() async {
    _tokens = null;
    await _tokenStore.clear();
  }
}
