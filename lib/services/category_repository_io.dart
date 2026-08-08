import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/product_category.dart';

class CategoryRepository {
  const CategoryRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<ProductCategory>> fetchCategories({
    bool includeInactive = true,
  }) async {
    final connection = await _open();
    try {
      final rows = await connection.execute('''
        SELECT
          categories.id,
          categories.name,
          categories.description,
          categories.image_path,
          categories.is_active,
          categories.created_at,
          categories.updated_at,
          COUNT(products.id)::int AS product_count
        FROM categories
        LEFT JOIN products ON products.category_id = categories.id
        ${includeInactive ? '' : 'WHERE categories.is_active = TRUE'}
        GROUP BY categories.id
        ORDER BY categories.is_active DESC, categories.name ASC
      ''');
      return rows
          .map((row) => ProductCategory.fromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<void> saveCategory(ProductCategory category) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          INSERT INTO categories (
            id, name, description, image_path, is_active, updated_at
          )
          VALUES (
            @id, @name, @description, NULLIF(@imagePath, ''), @isActive, NOW()
          )
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            image_path = EXCLUDED.image_path,
            is_active = EXCLUDED.is_active,
            updated_at = NOW()
        '''),
        parameters: {
          'id': category.id,
          'name': category.name,
          'description': category.description,
          'imagePath': category.imagePath ?? '',
          'isActive': category.isActive,
        },
      );
    } on UniqueViolationException {
      throw const CategoryException('Tên danh mục đã tồn tại.');
    } finally {
      await connection.close();
    }
  }

  Future<void> setActive({required String id, required bool isActive}) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          UPDATE categories
          SET is_active = @isActive
          WHERE id = @id
          RETURNING id
        '''),
        parameters: {'id': id, 'isActive': isActive},
      );
      if (rows.isEmpty) {
        throw const CategoryException('Không tìm thấy danh mục.');
      }
    } finally {
      await connection.close();
    }
  }

  Future<void> deleteCategory(String id) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          DELETE FROM categories
          WHERE id = @id
            AND NOT EXISTS (
              SELECT 1 FROM products WHERE products.category_id = categories.id
            )
          RETURNING id
        '''),
        parameters: {'id': id},
      );
      if (rows.isEmpty) {
        throw const CategoryException(
          'Danh mục đang có sản phẩm nên chỉ có thể tạm tắt.',
        );
      }
    } finally {
      await connection.close();
    }
  }

  Future<Connection> _open() => Connection.open(
    Endpoint(
      host: config.host,
      port: config.port,
      database: config.database,
      username: config.username,
      password: config.password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}

class CategoryException implements Exception {
  const CategoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
