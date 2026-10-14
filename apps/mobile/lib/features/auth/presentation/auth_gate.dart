import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({this.repository, super.key});

  final AuthRepository? repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _repository;
  AuthUser? _user;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? RemoteAuthRepository();
    _restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_user != null) {
      return AppShell(displayName: _user!.displayName);
    }
    return SignInScreen(
      onLogin: _login,
      onRegister: _register,
    );
  }

  Future<void> _restoreSession() async {
    AuthUser? restoredUser;
    try {
      restoredUser = await _repository.restoreSession();
    } catch (_) {
      restoredUser = null;
    }
    if (!mounted) return;
    setState(() {
      _user = restoredUser;
      _loading = false;
    });
  }

  Future<void> _login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final user = await _repository.login(
      email: email,
      password: password,
      remember: remember,
    );
    if (mounted) setState(() => _user = user);
  }

  Future<void> _register({
    required String displayName,
    required String studentId,
    required String email,
    required String password,
  }) async {
    final user = await _repository.register(
      displayName: displayName,
      studentId: studentId,
      email: email,
      password: password,
    );
    if (mounted) setState(() => _user = user);
  }
}
