import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_models.dart';
import 'auth_widgets.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.onLogin,
    required this.onRegister,
    super.key,
  });

  final Future<void> Function({
    required String email,
    required String password,
    required bool remember,
  }) onLogin;
  final RegisterCallback onRegister;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _rememberMe = true;
  var _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      title: 'Chào mừng trở lại',
      subtitle:
          'Đăng nhập để đặt phòng, mượn sách và khám phá các hoạt động tại trường.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              key: const Key('sign-in-email'),
              label: 'Email sinh viên',
              icon: Icons.mail_outline_rounded,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            const SizedBox(height: 10),
            AuthTextField(
              key: const Key('sign-in-password'),
              label: 'Mật khẩu',
              icon: Icons.lock_outline_rounded,
              controller: _passwordController,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) =>
                              setState(() => _rememberMe = value ?? false),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Ghi nhớ đăng nhập',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Luồng khôi phục mật khẩu sẽ được nối API sau.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  child: const Text('Quên mật khẩu?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(
              keyName: 'sign-in-submit',
              label: 'Đăng nhập',
              onPressed: _submit,
              loading: _loading,
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 16, color: AppTheme.cyan),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Thông tin của bạn được bảo vệ theo chính sách của nhà trường.',
                    style: TextStyle(color: Color(0xFF8A91A0), fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: AuthSwitchPrompt(
        message: 'Chưa có tài khoản?',
        action: 'Đăng ký',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SignUpScreen(
              onRegister: widget.onRegister,
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Vui lòng nhập email hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) return 'Mật khẩu cần ít nhất 6 ký tự';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await widget.onLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        remember: _rememberMe,
      );
    } on AuthApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Đã có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
