import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.showBackButton = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: showBackButton
                        ? IconButton.filled(
                            key: const Key('auth-back-button'),
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.navy,
                              shadowColor: Colors.black12,
                              elevation: 1,
                            ),
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 20),
                          )
                        : const Align(
                            alignment: Alignment.centerLeft,
                            child: _CampusWordmark(),
                          ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.blue,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.blue.withValues(alpha: .24),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7B8290),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: form,
                  ),
                  const SizedBox(height: 22),
                  Center(child: footer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.label,
    required this.icon,
    this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.validator,
    this.textInputAction,
    super.key,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late var _obscureText = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscureText,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: widget.label,
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        prefixIcon: Icon(widget.icon, size: 20, color: const Color(0xFF667085)),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscureText = !_obscureText),
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.keyName,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? keyName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: keyName == null ? null : Key(keyName!),
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.message,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: const TextStyle(color: Color(0xFF8A91A0))),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

class _CampusWordmark extends StatelessWidget {
  const _CampusWordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.school_rounded, color: AppTheme.blue),
        SizedBox(width: 8),
        Text(
          'CAMPUS HUB',
          style: TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      ],
    );
  }
}
