import 'package:flutter/material.dart';

import '../data/mock_products.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/postgres_product_repository.dart';
import '../services/category_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _productRepository = const PostgresProductRepository();
  final _categoryRepository = const CategoryRepository();
  final _searchController = TextEditingController();

  String _selectedCategory = 'Tất cả';
  String _query = '';
  List<Product> _allProducts = mockProducts;
  List<ProductCategory> _allCategories = const [];
  bool _isLoadingProducts = true;
  String? _productLoadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadProductsFromDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final values =
        _allCategories.isNotEmpty
              ? _allCategories.map((category) => category.name).toList()
              : _allProducts.map((product) => product.category).toSet().toList()
          ..sort();
    return ['Tất cả', ...values];
  }

  List<Product> get _products {
    return _allProducts.where((product) {
      final matchCategory =
          _selectedCategory == 'Tất cả' ||
          product.category == _selectedCategory;
      final matchQuery =
          _query.isEmpty ||
          product.name.toLowerCase().contains(_query) ||
          product.description.toLowerCase().contains(_query) ||
          product.category.toLowerCase().contains(_query);
      return matchCategory && matchQuery;
    }).toList();
  }

  Future<void> _loadProductsFromDatabase() async {
    try {
      final result = await Future.wait<Object>([
        _productRepository.fetchProducts(),
        _categoryRepository.fetchCategories(includeInactive: false),
      ]);
      final products = result[0] as List<Product>;
      final categories = result[1] as List<ProductCategory>;
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _allCategories = categories;
        _isLoadingProducts = false;
        _productLoadError = null;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Tất cả';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _allProducts = mockProducts;
        _allCategories = const [];
        _isLoadingProducts = false;
        _productLoadError = error.toString();
      });
    }
  }

  void _openDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _quickAdd(Product product) {
    CartScope.of(context).addProduct(
      product: product,
      size: 'M',
      sugar: '70%',
      ice: 'Vừa',
      note: '',
      quantity: 1,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${product.name} vào giỏ hàng.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.coffeeDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProductsFromDatabase,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
            children: [
              _HomeHeader(name: user?.fullName ?? 'bạn'),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm cà phê, trà sữa, bánh ngọt...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xoá tìm kiếm',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              const _PromoStrip(),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Danh mục',
                trailing: _isLoadingProducts
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              _CategoryRail(
                categories: _categories,
                selectedCategory: _selectedCategory,
                onSelected: (value) =>
                    setState(() => _selectedCategory = value),
              ),
              const SizedBox(height: 22),
              const _SectionHeader(title: 'Menu hôm nay'),
              const SizedBox(height: 12),
              if (_productLoadError != null) ...[
                const _DatabaseNotice(),
                const SizedBox(height: 12),
              ],
              if (_products.isEmpty)
                const _EmptyMenu()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return ProductCard(
                      product: product,
                      onTap: () => _openDetail(product),
                      onAdd: () => _quickAdd(product),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Coffee Việt 24H',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chào $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _PromoStrip extends StatelessWidget {
  const _PromoStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.coffeeDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_cafe_rounded,
              color: AppColors.coffee,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Combo buổi sáng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mua 2 ly bất kỳ giảm 20% cho đơn từ 70.000đ.',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            label: Text(category),
            onSelected: (_) => onSelected(category),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: AppColors.coffee,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.coffee : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _DatabaseNotice extends StatelessWidget {
  const _DatabaseNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.storage_rounded, color: AppColors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Không kết nối được PostgreSQL, đang dùng dữ liệu mẫu.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.local_cafe_rounded, size: 42, color: AppColors.border),
          SizedBox(height: 8),
          Text(
            'Không tìm thấy món phù hợp',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
