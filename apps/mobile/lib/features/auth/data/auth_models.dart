class AuthUser {
  const AuthUser({
    required this.id,
    required this.institutionId,
    required this.studentId,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String institutionId;
  final String studentId;
  final String email;
  final String displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      institutionId: json['institutionId'] as String,
      studentId: json['studentId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json),
    );
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
