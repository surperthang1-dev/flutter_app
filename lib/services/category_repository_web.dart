import '../config/database_config.dart';
import '../models/product_category.dart';

class CategoryRepository {
  const CategoryRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<ProductCategory>> fetchCategories({
    bool includeInactive = true,
  }) => throw _error();
  Future<void> saveCategory(ProductCategory category) => throw _error();
  Future<void> setActive({required String id, required bool isActive}) =>
      throw _error();
  Future<void> deleteCategory(String id) => throw _error();

  UnsupportedError _error() => UnsupportedError(
    'Bản Chrome/web không thể quản trị PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
  );
}

class CategoryException implements Exception {
  const CategoryException(this.message);
  final String message;
  @override
  String toString() => message;
}
