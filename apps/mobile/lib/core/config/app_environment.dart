abstract final class AppEnvironment {
  static const institutionCode = String.fromEnvironment(
    'INSTITUTION_CODE',
    defaultValue: 'CAMPUS',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
