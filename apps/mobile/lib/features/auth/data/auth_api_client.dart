import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/app_environment.dart';
import 'auth_models.dart';

class AuthApiClient {
  AuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/login', {
      'institutionCode': AppEnvironment.institutionCode,
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> register({
    required String displayName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/register', {
      'institutionCode': AppEnvironment.institutionCode,
      'studentId': studentId,
      'displayName': displayName,
      'email': email,
      'password': password,
    });
    return AuthSession.fromJson(json);
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    final json = await _post('/auth/refresh', {'refreshToken': refreshToken});
    return AuthTokens.fromJson(json);
  }

  Future<AuthUser> me(String accessToken) async {
    final response = await _send(
      () => _client.get(
        _uri('/auth/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return AuthUser.fromJson(_decode(response));
  }

  Future<void> logout(String accessToken) async {
    final response = await _send(
      () => _client.post(
        _uri('/auth/logout'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    if (response.statusCode != HttpStatus.noContent) {
      _throwResponse(response);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => _client.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const AuthApiException(
        'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } on SocketException {
      throw const AuthApiException(
        'Không thể kết nối máy chủ. Hãy kiểm tra NestJS đang chạy.',
      );
    } on http.ClientException {
      throw const AuthApiException('Không thể kết nối máy chủ Campus Hub.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponse(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AuthApiException('Phản hồi từ máy chủ không hợp lệ.');
    }
    return decoded;
  }

  Never _throwResponse(http.Response response) {
    var message = 'Yêu cầu không thành công.';
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final serverMessage = decoded['message'];
      if (serverMessage is String) message = serverMessage;
      if (serverMessage is List) message = serverMessage.join('\n');
    } catch (_) {
      // Keep the safe fallback when the server did not return JSON.
    }
    throw AuthApiException(message, statusCode: response.statusCode);
  }

  Uri _uri(String path) => Uri.parse('${AppEnvironment.apiBaseUrl}$path');
}
