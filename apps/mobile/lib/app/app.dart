import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';

class CampusHubApp extends StatelessWidget {
  const CampusHubApp({this.authRepository, super.key});

  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(repository: authRepository),
    );
  }
}
