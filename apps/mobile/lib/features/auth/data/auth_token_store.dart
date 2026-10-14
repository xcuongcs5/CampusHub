import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'campus_hub_access_token';
  static const _refreshTokenKey = 'campus_hub_refresh_token';

  final FlutterSecureStorage _storage;

  Future<AuthTokens?> read() async {
    final values = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
    ]);
    if (values[0] == null || values[1] == null) return null;
    return AuthTokens(accessToken: values[0]!, refreshToken: values[1]!);
  }

  Future<void> write(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
