import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_user.dart';
import '../models/delivery_area.dart';
import '../providers/auth_provider.dart';
import '../services/delivery_area_repository.dart';
import '../services/postgres_auth_repository.dart';
import '../services/registration_validator.dart';
import '../utils/app_colors.dart';
import '../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Form hồ sơ dùng lại validator đăng ký để dữ liệu user luôn hợp lệ với trigger DB.
  final _formKey = GlobalKey<FormState>();
  final _repository = const PostgresAuthRepository();
  final _areaRepository = const DeliveryAreaRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _addressNoteController;
  final _currentPasswordController = TextEditingController();

  List<DeliveryArea> _areas = const [];
  String? _selectedAreaId;
  bool _isLoadingAreas = true;
  bool _isSaving = false;
  bool _obscureCurrentPassword = true;
  String? _areaLoadError;

  bool get _isChangingPhone =>
      _phoneController.text.trim() != widget.user.phone.trim();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _addressController = TextEditingController(
      text: widget.user.addressDetail ?? widget.user.address ?? '',
    );
    _addressNoteController = TextEditingController(
      text: widget.user.addressNote ?? '',
    );
    _selectedAreaId = widget.user.deliveryAreaId;
    _loadAreas();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _addressNoteController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    // Chỉ tải khu vực active để user không thể chọn nơi quán đang tạm ngừng phục vụ.
    setState(() {
      _isLoadingAreas = true;
      _areaLoadError = null;
    });
    try {
      final areas = await _areaRepository.fetchAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        if (!areas.any((area) => area.id == _selectedAreaId)) {
          _selectedAreaId = null;
        }
        _isLoadingAreas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingAreas = false;
        _areaLoadError = error.toString();
      });
    }
  }

  Future<void> _save() async {
    // Đổi số điện thoại sẽ yêu cầu mật khẩu hiện tại ở repository và PostgreSQL.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoadingAreas || _areas.isEmpty) {
      _showMessage('Chưa tải được khu vực giao hàng. Vui lòng thử lại.');
      return;
    }

    final auth = AuthScope.of(context);
    final currentUser = auth.user;
    if (currentUser == null) {
      _showMessage('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedUser = await _repository.updateProfile(
        user: currentUser,
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        addressDetail: _addressController.text,
        addressNote: _addressNoteController.text,
        deliveryAreaId: _selectedAreaId!,
        currentPassword: _currentPasswordController.text,
      );
      if (!mounted) return;
      auth.updateUser(updatedUser);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin tài khoản.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Không thể cập nhật tài khoản. Vui lòng thử lại.');
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
      appBar: AppBar(title: const Text('Chỉnh sửa tài khoản')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              const _IntroCard(),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: RegistrationValidator.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: '0901234567',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: RegistrationValidator.phone,
              ),
              if (_isChangingPhone) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại để xác nhận',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscureCurrentPassword
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                      onPressed: () => setState(
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
                      ),
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  validator: (value) => _isChangingPhone
                      ? RegistrationValidator.password(value)
                      : null,
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email (không bắt buộc)',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: RegistrationValidator.email,
              ),
              const SizedBox(height: 22),
              const _FormSectionLabel('Địa chỉ giao hàng mặc định'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Số nhà, tên đường',
                  prefixIcon: Icon(Icons.home_rounded),
                ),
                validator: RegistrationValidator.addressDetail,
              ),
              const SizedBox(height: 14),
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
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                        child: Text(area.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _isLoadingAreas || _areas.isEmpty
                    ? null
                    : (value) => setState(() => _selectedAreaId = value),
                validator: RegistrationValidator.deliveryAreaId,
              ),
              if (_areaLoadError != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loadAreas,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tải lại khu vực giao hàng'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressNoteController,
                minLines: 1,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú địa chỉ',
                  hintText: 'Tòa nhà, tầng, gọi trước khi giao...',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: RegistrationValidator.addressNote,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                icon: Icons.save_rounded,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.caramel.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.coffee),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Địa chỉ và số điện thoại được dùng cho các đơn đặt sau này. Đổi số điện thoại cần xác nhận mật khẩu hiện tại.',
              style: TextStyle(
                color: AppColors.textMuted,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
