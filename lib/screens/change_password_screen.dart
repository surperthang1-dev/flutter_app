import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/postgres_auth_repository.dart';
import '../services/registration_validator.dart';
import '../utils/app_colors.dart';
import '../widgets/primary_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = const PostgresAuthRepository();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await _repository.changePassword(
        user: widget.user,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đổi mật khẩu. Hãy giữ mật khẩu mới an toàn.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể đổi mật khẩu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.caramel.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, color: AppColors.coffee),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nhập mật khẩu hiện tại để bảo vệ tài khoản. Mật khẩu mới cần có ít nhất 6 ký tự.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _PasswordField(
                controller: _currentPasswordController,
                label: 'Mật khẩu hiện tại',
                obscureText: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                validator: RegistrationValidator.password,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _newPasswordController,
                label: 'Mật khẩu mới',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) {
                  final error = RegistrationValidator.password(value);
                  if (error != null) return error;
                  if (value == _currentPasswordController.text) {
                    return 'Mật khẩu mới cần khác mật khẩu hiện tại.';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirmPasswordController,
                label: 'Xác nhận mật khẩu mới',
                obscureText: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) => RegistrationValidator.confirmation(
                  password: _newPasswordController.text,
                  value: value,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _changePassword(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSaving ? 'Đang đổi mật khẩu...' : 'Đổi mật khẩu',
                icon: Icons.lock_rounded,
                onPressed: _isSaving ? null : _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
    required this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
          ),
        ),
      ),
      validator: validator,
    );
  }
}
