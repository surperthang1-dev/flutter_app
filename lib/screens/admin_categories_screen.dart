import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../services/category_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/primary_button.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  // Danh mục quyết định cách nhóm menu user; danh mục có món chỉ được tạm tắt, không xóa cứng.
  final _repository = const CategoryRepository();
  final _searchController = TextEditingController();
  late Future<List<ProductCategory>> _future;
  String _query = '';
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchCategories();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchCategories();
    });
  }

  Future<void> _openEditor([ProductCategory? category]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CategoryEditor(category: category, onSave: _repository.saveCategory),
    );
    if (saved == true) _refresh();
  }

  Future<void> _setActive(ProductCategory category, bool isActive) async {
    if (_updatingId != null) return;
    setState(() => _updatingId = category.id);
    try {
      await _repository.setActive(id: category.id, isActive: isActive);
      if (!mounted) return;
      _refresh();
    } catch (error) {
      if (!mounted) return;
      _message('Không thể cập nhật danh mục: $error');
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Future<void> _delete(ProductCategory category) async {
    // Khi đã có sản phẩm, UI chuyển sang lựa chọn deactivate để không làm hỏng liên kết DB.
    final hasProducts = category.productCount > 0;
    final action = await showDialog<_CategoryDeleteAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          hasProducts ? 'Danh mục đang được sử dụng' : 'Xoá danh mục',
        ),
        content: Text(
          hasProducts
              ? '“${category.name}” có ${category.productCount} sản phẩm. Danh mục không thể xoá cứng, nhưng có thể tạm tắt khỏi khu vực mua hàng.'
              : 'Xoá vĩnh viễn danh mục “${category.name}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: hasProducts
                ? null
                : FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(
              hasProducts
                  ? _CategoryDeleteAction.deactivate
                  : _CategoryDeleteAction.delete,
            ),
            child: Text(hasProducts ? 'Tạm tắt' : 'Xoá'),
          ),
        ],
      ),
    );
    if (action == null) return;
    try {
      if (action == _CategoryDeleteAction.deactivate) {
        await _repository.setActive(id: category.id, isActive: false);
      } else {
        await _repository.deleteCategory(category.id);
      }
      if (!mounted) return;
      _refresh();
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductCategory>>(
      future: _future,
      builder: (context, snapshot) {
        final categories = (snapshot.data ?? const <ProductCategory>[])
            .where(
              (category) =>
                  _query.isEmpty ||
                  category.name.toLowerCase().contains(_query) ||
                  category.description.toLowerCase().contains(_query),
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
                      'Danh mục',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Thêm danh mục',
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm danh mục',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _CategoryState(
                  icon: Icons.error_outline_rounded,
                  title: 'Không thể tải danh mục',
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Tải lại'),
                  ),
                )
              else if (categories.isEmpty)
                const _CategoryState(
                  icon: Icons.category_outlined,
                  title: 'Chưa có danh mục phù hợp',
                )
              else
                ...categories.map(
                  (category) => _CategoryTile(
                    category: category,
                    isUpdating: _updatingId == category.id,
                    onEdit: () => _openEditor(category),
                    onDelete: () => _delete(category),
                    onChanged: (value) => _setActive(category, value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isUpdating,
    required this.onEdit,
    required this.onDelete,
    required this.onChanged,
  });

  final ProductCategory category;
  final bool isUpdating;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: category.isActive
                ? AppColors.caramel.withValues(alpha: 0.14)
                : AppColors.mutedSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.category_rounded,
            color: category.isActive ? AppColors.caramel : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${category.productCount} sản phẩm${category.isActive ? '' : ' · Đã tắt'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: category.isActive,
          onChanged: isUpdating ? null : onChanged,
        ),
        IconButton(
          tooltip: 'Sửa danh mục',
          onPressed: isUpdating ? null : onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Xoá danh mục',
          onPressed: isUpdating ? null : onDelete,
          color: Colors.red.shade700,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.category, required this.onSave});

  final ProductCategory? category;
  final Future<void> Function(ProductCategory category) onSave;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imagePathController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _descriptionController = TextEditingController(
      text: category?.description ?? '',
    );
    _imagePathController = TextEditingController(
      text: category?.imagePath ?? '',
    );
    _isActive = category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imagePathController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    final current = widget.category;
    try {
      await widget.onSave(
        ProductCategory(
          id: current?.id ?? 'CAT-${DateTime.now().microsecondsSinceEpoch}',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imagePath: _imagePathController.text.trim().isEmpty
              ? null
              : _imagePathController.text.trim(),
          isActive: _isActive,
          productCount: current?.productCount ?? 0,
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
                  widget.category == null ? 'Thêm danh mục' : 'Sửa danh mục',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Vui lòng nhập tên danh mục.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imagePathController,
                  decoration: const InputDecoration(
                    labelText: 'Đường dẫn ảnh (không bắt buộc)',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị cho khách hàng'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _isSaving ? 'Đang lưu...' : 'Lưu danh mục',
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

class _CategoryState extends StatelessWidget {
  const _CategoryState({required this.icon, required this.title, this.action});

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

enum _CategoryDeleteAction { deactivate, delete }
