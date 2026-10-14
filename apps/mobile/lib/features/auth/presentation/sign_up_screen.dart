import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_models.dart';
import 'auth_widgets.dart';

typedef RegisterCallback = Future<void> Function({
  required String displayName,
  required String studentId,
  required String email,
  required String password,
});

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({required this.onRegister, super.key});

  final RegisterCallback onRegister;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _acceptedTerms = true;
  var _loading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      showBackButton: true,
      title: 'Tạo tài khoản của bạn',
      subtitle:
          'Bắt đầu sử dụng các tiện ích sinh viên nhanh chóng và thuận tiện hơn.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              key: const Key('sign-up-name'),
              label: 'Họ và tên',
              icon: Icons.person_outline_rounded,
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 10),
            AuthTextField(
              label: 'Mã số sinh viên',
              icon: Icons.badge_outlined,
              controller: _studentIdController,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 10),
            AuthTextField(
              key: const Key('sign-up-email'),
              label: 'Email sinh viên',
              icon: Icons.mail_outline_rounded,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final email = value?.trim() ?? '';
                return email.contains('@') && email.contains('.')
                    ? null
                    : 'Vui lòng nhập email hợp lệ';
              },
            ),
            const SizedBox(height: 10),
            AuthTextField(
              key: const Key('sign-up-password'),
              label: 'Mật khẩu',
              icon: Icons.lock_outline_rounded,
              controller: _passwordController,
              isPassword: true,
              validator: (value) => (value ?? '').length >= 8
                  ? null
                  : 'Mật khẩu cần ít nhất 8 ký tự',
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value ?? false),
                  ),
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text.rich(
                      TextSpan(
                        style:
                            TextStyle(color: Color(0xFF8A91A0), fontSize: 11),
                        children: [
                          TextSpan(text: 'Bằng việc tiếp tục, bạn đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản sử dụng',
                            style: TextStyle(
                                color: AppTheme.blue,
                                fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' và Chính sách bảo mật.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AuthPrimaryButton(
              keyName: 'sign-up-submit',
              label: 'Tạo tài khoản',
              onPressed: _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
      footer: AuthSwitchPrompt(
        message: 'Đã có tài khoản?',
        action: 'Đăng nhập',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  String? _required(String? value) {
    return (value?.trim().isEmpty ?? true) ? 'Thông tin này là bắt buộc' : null;
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đồng ý với điều khoản để tiếp tục.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await widget.onRegister(
        displayName: _displayNameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.pop(context);
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
