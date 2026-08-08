import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery_area.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_area_repository.dart';
import '../services/postgres_auth_repository.dart';
import '../services/registration_validator.dart';
import '../utils/app_colors.dart';
import '../widgets/coffee_logo.dart';
import '../widgets/primary_button.dart';
import 'main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNoteController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = const PostgresAuthRepository();
  final _areaRepository = const DeliveryAreaRepository();

  List<DeliveryArea> _areas = const [];
  String? _selectedAreaId;
  String? _areaLoadError;
  bool _isLoadingAreas = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _addressNoteController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoadingAreas = true;
      _areaLoadError = null;
    });
    try {
      final areas = await _areaRepository.fetchAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _isLoadingAreas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _areaLoadError = error.toString();
        _isLoadingAreas = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final user = await _authRepository.register(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        addressDetail: _addressController.text.trim(),
        addressNote: _addressNoteController.text.trim(),
        deliveryAreaId: _selectedAreaId!,
        password: _passwordController.text,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 40,
          ),
          title: const Text('Đăng ký thành công'),
          content: const Text(
            'Tài khoản của bạn đã sẵn sàng. Bạn có thể bắt đầu chọn món.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bắt đầu'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      AuthScope.of(context).signIn(user);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.coffeeDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const Center(child: CoffeeLogo(size: 74)),
              const SizedBox(height: 26),
              Text(
                'Tạo tài khoản',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Lưu địa chỉ giao hàng để tính đúng phí và phục vụ nhanh hơn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              _AuthPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: RegistrationValidator.fullName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          hintText: '0901234567',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        validator: RegistrationValidator.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email (không bắt buộc)',
                          hintText: 'ban@example.com',
                          prefixIcon: Icon(Icons.mail_rounded),
                        ),
                        validator: RegistrationValidator.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        minLines: 2,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Số nhà, tên đường',
                          hintText: 'Ví dụ: 12 Nguyễn Huệ, phường Bến Nghé',
                          prefixIcon: Icon(Icons.home_rounded),
                        ),
                        validator: RegistrationValidator.addressDetail,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAreaId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Khu vực giao hàng',
                          prefixIcon: const Icon(Icons.location_on_rounded),
                          suffixIcon: _isLoadingAreas
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        hint: Text(
                          _areaLoadError == null
                              ? 'Chọn khu vực được hỗ trợ'
                              : 'Không tải được khu vực',
                        ),
                        items: _areas
                            .map(
                              (area) => DropdownMenuItem(
                                value: area.id,
                                child: Text(
                                  area.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isLoadingAreas || _areas.isEmpty
                            ? null
                            : (value) =>
                                  setState(() => _selectedAreaId = value),
                        validator: RegistrationValidator.deliveryAreaId,
                      ),
                      if (_areaLoadError != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _loadAreas,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tải lại khu vực giao hàng'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressNoteController,
                        minLines: 1,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú địa chỉ',
                          hintText: 'Ví dụ: Tòa nhà, tầng, gọi trước khi giao',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        validator: RegistrationValidator.addressNote,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: RegistrationValidator.password,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        onFieldSubmitted: (_) => _register(),
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          prefixIcon: const Icon(Icons.verified_user_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            RegistrationValidator.confirmation(
                              password: _passwordController.text,
                              value: value,
                            ),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: _isLoading ? 'Đang tạo tài khoản...' : 'Đăng ký',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: _isLoading ? null : _register,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.coffeeDark.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
