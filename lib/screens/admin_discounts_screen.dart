import 'package:flutter/material.dart';

import '../models/discount_code.dart';
import '../services/discount_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';

class AdminDiscountsPage extends StatefulWidget {
  const AdminDiscountsPage({super.key});

  @override
  State<AdminDiscountsPage> createState() => _AdminDiscountsPageState();
}

class _AdminDiscountsPageState extends State<AdminDiscountsPage> {
  // Quản lý toàn bộ vòng đời mã giảm giá: tạo, sửa, bật/tắt và lọc theo hiệu lực.
  final _repository = const DiscountRepository();
  final _searchController = TextEditingController();
  late Future<List<DiscountCode>> _future;
  String _query = '';
  _DiscountFilter _filter = _DiscountFilter.all;
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchDiscountCodes();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toUpperCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchDiscountCodes();
    });
  }

  Future<void> _openEditor([DiscountCode? discount]) async {
    // Cùng một editor được dùng cho cả tạo mới và chỉnh sửa mã giảm giá.
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiscountEditor(
        discount: discount,
        onSave: _repository.saveDiscountCode,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _setActive(DiscountCode discount, bool value) async {
    if (_updatingId != null) return;
    setState(() => _updatingId = discount.id);
    try {
      await _repository.setActive(id: discount.id, isActive: value);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message('Không thể cập nhật mã: $error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _matchesFilter(DiscountCode discount, DateTime now) {
    return switch (_filter) {
      _DiscountFilter.all => true,
      _DiscountFilter.active =>
        discount.isActive &&
            !now.isBefore(discount.startAt) &&
            !now.isAfter(discount.endAt) &&
            discount.isUsageAvailable,
      _DiscountFilter.expired => now.isAfter(discount.endAt),
      _DiscountFilter.disabled => !discount.isActive,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DiscountCode>>(
      future: _future,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final discounts = (snapshot.data ?? const <DiscountCode>[])
            .where(
              (discount) =>
                  _matchesFilter(discount, now) &&
                  (_query.isEmpty ||
                      discount.code.contains(_query) ||
                      discount.description.toUpperCase().contains(_query)),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mã giảm giá',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Thêm mã giảm giá',
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Tìm mã giảm giá',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _DiscountFilter.values
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _DiscountState(
                  icon: Icons.error_outline_rounded,
                  title: 'Không thể tải mã giảm giá',
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Tải lại'),
                  ),
                )
              else if (discounts.isEmpty)
                const _DiscountState(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Chưa có mã phù hợp',
                )
              else
                ...discounts.map(
                  (discount) => _DiscountTile(
                    discount: discount,
                    now: now,
                    isUpdating: _updatingId == discount.id,
                    onEdit: () => _openEditor(discount),
                    onChanged: (value) => _setActive(discount, value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DiscountTile extends StatelessWidget {
  const _DiscountTile({
    required this.discount,
    required this.now,
    required this.isUpdating,
    required this.onEdit,
    required this.onChanged,
  });

  final DiscountCode discount;
  final DateTime now;
  final bool isUpdating;
  final VoidCallback onEdit;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final status = _discountStatus(discount, now);
    final color = switch (status) {
      _DiscountStatus.active => AppColors.success,
      _DiscountStatus.expired => AppColors.textMuted,
      _DiscountStatus.disabled => Colors.red.shade700,
      _DiscountStatus.scheduled => AppColors.caramel,
      _DiscountStatus.usedUp => AppColors.orange,
    };
    final value = discount.type == DiscountType.fixed
        ? formatVnd(discount.discountValue)
        : '${discount.discountValue}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  discount.code,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(label: status.label, color: color),
              IconButton(
                tooltip: 'Sửa mã giảm giá',
                onPressed: isUpdating ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          Text(
            '$value · Đơn từ ${formatVnd(discount.minimumOrderValue)}',
            style: const TextStyle(
              color: AppColors.coffee,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (discount.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              discount.description,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_dateLabel(discount.startAt)} – ${_dateLabel(discount.endAt)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${discount.usedCount}/${discount.usageLimit?.toString() ?? '∞'} lượt',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Switch(
                value: discount.isActive,
                onChanged: isUpdating ? null : onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscountEditor extends StatefulWidget {
  const _DiscountEditor({required this.discount, required this.onSave});

  final DiscountCode? discount;
  final Future<void> Function(DiscountCode discount) onSave;

  @override
  State<_DiscountEditor> createState() => _DiscountEditorState();
}

class _DiscountEditorState extends State<_DiscountEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _valueController;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late final TextEditingController _usageLimitController;
  late DiscountType _type;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final discount = widget.discount;
    final now = DateTime.now();
    _codeController = TextEditingController(text: discount?.code ?? '');
    _descriptionController = TextEditingController(
      text: discount?.description ?? '',
    );
    _valueController = TextEditingController(
      text: discount?.discountValue.toString() ?? '',
    );
    _minimumController = TextEditingController(
      text: discount?.minimumOrderValue.toString() ?? '0',
    );
    _maximumController = TextEditingController(
      text: discount?.maximumDiscount?.toString() ?? '',
    );
    _usageLimitController = TextEditingController(
      text: discount?.usageLimit?.toString() ?? '',
    );
    _type = discount?.type ?? DiscountType.fixed;
    _startAt = discount?.startAt ?? now;
    _endAt = discount?.endAt ?? now.add(const Duration(days: 30));
    _isActive = discount?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    _minimumController.dispose();
    _maximumController.dispose();
    _usageLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startAt : _endAt,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startAt = DateTime(picked.year, picked.month, picked.day);
        if (!_endAt.isAfter(_startAt)) {
          _endAt = _startAt.add(const Duration(days: 1));
        }
      } else {
        _endAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (!_endAt.isAfter(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày kết thúc phải sau ngày bắt đầu.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final current = widget.discount;
    try {
      await widget.onSave(
        DiscountCode(
          id: current?.id ?? 'DC-${DateTime.now().microsecondsSinceEpoch}',
          code: _codeController.text.trim().toUpperCase(),
          description: _descriptionController.text.trim(),
          type: _type,
          discountValue: int.parse(_valueController.text.trim()),
          minimumOrderValue: int.parse(_minimumController.text.trim()),
          maximumDiscount: _optionalNumber(_maximumController.text),
          usageLimit: _optionalNumber(_usageLimitController.text),
          usedCount: current?.usedCount ?? 0,
          startAt: _startAt,
          endAt: _endAt,
          isActive: _isActive,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int? _optionalNumber(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  String? _requiredNumber(String? value, {bool positive = false}) {
    final number = int.tryParse((value ?? '').trim());
    if (number == null || number < 0 || (positive && number == 0)) {
      return positive ? 'Nhập số lớn hơn 0.' : 'Nhập số không âm.';
    }
    if (_type == DiscountType.percentage &&
        identical(value, _valueController.text) &&
        number > 100) {
      return 'Phần trăm không vượt quá 100.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.discount == null
                      ? 'Thêm mã giảm giá'
                      : 'Sửa mã giảm giá',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Mã giảm giá'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Vui lòng nhập mã giảm giá.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DiscountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Loại giảm'),
                  items: DiscountType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _type == DiscountType.fixed
                        ? 'Giá trị giảm (đ)'
                        : 'Phần trăm giảm',
                  ),
                  validator: (value) {
                    final result = _requiredNumber(value, positive: true);
                    final number = int.tryParse((value ?? '').trim());
                    if (result == null &&
                        _type == DiscountType.percentage &&
                        number! > 100) {
                      return 'Phần trăm không vượt quá 100.';
                    }
                    return result;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minimumController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Đơn tối thiểu',
                        ),
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maximumController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giảm tối đa',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          return _requiredNumber(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usageLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giới hạn lượt dùng (để trống = không giới hạn)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return null;
                    return _requiredNumber(value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(start: true),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Bắt đầu: ${_dateLabel(_startAt)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(start: false),
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text('Kết thúc: ${_dateLabel(_endAt)}'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang bật'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: _isSaving ? 'Đang lưu...' : 'Lưu mã giảm giá',
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

class _DiscountState extends StatelessWidget {
  const _DiscountState({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.caramel),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
    ),
  );
}

enum _DiscountFilter { all, active, expired, disabled }

extension on _DiscountFilter {
  String get label => switch (this) {
    _DiscountFilter.all => 'Tất cả',
    _DiscountFilter.active => 'Còn hiệu lực',
    _DiscountFilter.expired => 'Hết hạn',
    _DiscountFilter.disabled => 'Đã tắt',
  };
}

enum _DiscountStatus { active, expired, disabled, scheduled, usedUp }

_DiscountStatus _discountStatus(DiscountCode discount, DateTime now) {
  if (!discount.isActive) return _DiscountStatus.disabled;
  if (now.isBefore(discount.startAt)) return _DiscountStatus.scheduled;
  if (now.isAfter(discount.endAt)) return _DiscountStatus.expired;
  if (!discount.isUsageAvailable) return _DiscountStatus.usedUp;
  return _DiscountStatus.active;
}

extension on _DiscountStatus {
  String get label => switch (this) {
    _DiscountStatus.active => 'Đang bật',
    _DiscountStatus.expired => 'Hết hạn',
    _DiscountStatus.disabled => 'Đã tắt',
    _DiscountStatus.scheduled => 'Sắp mở',
    _DiscountStatus.usedUp => 'Hết lượt',
  };
}

String _dateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
