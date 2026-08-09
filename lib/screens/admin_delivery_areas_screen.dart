import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery_area.dart';
import '../services/delivery_area_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';

class AdminDeliveryAreasScreen extends StatefulWidget {
  const AdminDeliveryAreasScreen({super.key});

  @override
  State<AdminDeliveryAreasScreen> createState() =>
      _AdminDeliveryAreasScreenState();
}

class _AdminDeliveryAreasScreenState extends State<AdminDeliveryAreasScreen> {
  final _repository = const DeliveryAreaRepository();
  final _searchController = TextEditingController();
  late Future<List<DeliveryArea>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchAreas(includeInactive: true);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    late final Future<List<DeliveryArea>> future;
    setState(() {
      future = _repository.fetchAreas(includeInactive: true);
      _future = future;
    });
    await future;
  }

  Future<void> _edit(DeliveryArea area) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeliveryAreaEditor(area: area, repository: _repository),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu phí và trạng thái phục vụ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<DeliveryArea>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDeliveryAreaSheet(repository: _repository),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm khu vực ${created.name}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Khu vực & phí giao hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.coffee,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Thêm khu vực'),
      ),
      body: FutureBuilder<List<DeliveryArea>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _AreaMessage(
              icon: Icons.error_outline_rounded,
              text: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          final areas = snapshot.data!
              .where((area) => area.name.toLowerCase().contains(_query))
              .toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28 + 76),
              children: [
                const Text(
                  'Thay đổi phí chỉ áp dụng cho đơn hàng tạo sau khi lưu. Đơn cũ giữ nguyên snapshot phí giao hàng.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.35),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Tìm khu vực giao hàng',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                if (areas.isEmpty)
                  const _AreaMessage(
                    icon: Icons.location_off_rounded,
                    text: 'Không tìm thấy khu vực phù hợp.',
                  )
                else
                  ...areas.map(
                    (area) => _DeliveryAreaTile(
                      area: area,
                      onEdit: () => _edit(area),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeliveryAreaTile extends StatelessWidget {
  const _DeliveryAreaTile({required this.area, required this.onEdit});

  final DeliveryArea area;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = area.isActive ? AppColors.success : Colors.red.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.location_on_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phí giao hàng: ${formatVnd(area.shippingFee)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  area.isActive ? 'Đang phục vụ' : 'Tạm ngừng phục vụ',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Chỉnh sửa',
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }
}

class _DeliveryAreaEditor extends StatefulWidget {
  const _DeliveryAreaEditor({required this.area, required this.repository});

  final DeliveryArea area;
  final DeliveryAreaRepository repository;

  @override
  State<_DeliveryAreaEditor> createState() => _DeliveryAreaEditorState();
}

class _CreateDeliveryAreaSheet extends StatefulWidget {
  const _CreateDeliveryAreaSheet({required this.repository});

  final DeliveryAreaRepository repository;

  @override
  State<_CreateDeliveryAreaSheet> createState() =>
      _CreateDeliveryAreaSheetState();
}

class _CreateDeliveryAreaSheetState extends State<_CreateDeliveryAreaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final area = await widget.repository.createArea(
        name: _nameController.text,
        shippingFee: int.parse(_feeController.text),
        isActive: _isActive,
      );
      if (mounted) Navigator.of(context).pop(area);
    } on DeliveryAreaException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể thêm khu vực. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Thêm khu vực giao hàng',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Khu vực đang phục vụ sẽ tự xuất hiện trong form đăng ký và cập nhật địa chỉ của user.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.35),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên khu vực',
                    hintText: 'Ví dụ: Quận 10',
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Vui lòng nhập tên khu vực.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Phí giao hàng (đ)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final fee = int.tryParse((value ?? '').trim());
                    if (fee == null || fee < 0) {
                      return 'Nhập phí giao hàng từ 0 trở lên.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bắt đầu phục vụ ngay'),
                  subtitle: const Text(
                    'Nếu tắt, khu vực được lưu nhưng chưa hiển thị cho user.',
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _isSaving ? 'Đang thêm...' : 'Thêm khu vực',
                  icon: Icons.add_location_alt_rounded,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryAreaEditorState extends State<_DeliveryAreaEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _feeController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(
      text: widget.area.shippingFee.toString(),
    );
    _isActive = widget.area.isActive;
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.updateArea(
        id: widget.area.id,
        shippingFee: int.parse(_feeController.text),
        isActive: _isActive,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.area.name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Phí giao hàng (đ)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final fee = int.tryParse((value ?? '').trim());
                    if (fee == null || fee < 0) {
                      return 'Nhập phí giao hàng từ 0 trở lên.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhận giao hàng tại khu vực này'),
                  subtitle: Text(
                    _isActive
                        ? 'User có thể tạo đơn mới đến khu vực này.'
                        : 'User hiện có vẫn giữ địa chỉ, nhưng không thể tạo đơn mới.',
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                  icon: Icons.save_rounded,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaMessage extends StatelessWidget {
  const _AreaMessage({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.caramel, size: 42),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ],
    ),
  );
}
