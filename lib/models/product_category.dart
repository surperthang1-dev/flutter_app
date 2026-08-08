class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.productCount,
    this.imagePath,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductCategory.fromColumnMap(Map<String, dynamic> data) {
    return ProductCategory(
      id: data['id'] as String,
      name: data['name'] as String,
      description: (data['description'] as String?) ?? '',
      imagePath: data['image_path'] as String?,
      isActive: data['is_active'] as bool,
      productCount: (data['product_count'] as num?)?.toInt() ?? 0,
      createdAt: data['created_at'] as DateTime?,
      updatedAt: data['updated_at'] as DateTime?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String? imagePath;
  final bool isActive;
  final int productCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
