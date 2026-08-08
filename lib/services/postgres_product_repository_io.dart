import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/product.dart';

class PostgresProductRepository {
  const PostgresProductRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<Product>> fetchProducts() async {
    final connection = await Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username,
        password: config.password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    try {
      final rows = await connection.execute('''
        SELECT
          products.id,
          products.name,
          products.description,
          products.price,
          categories.name AS category,
          products.category_id,
          products.image_label,
          products.accent_color,
          products.image_asset
        FROM products
        INNER JOIN categories ON categories.id = products.category_id
        WHERE products.is_active = TRUE
          AND categories.is_active = TRUE
        ORDER BY products.sort_order ASC, products.name ASC
        ''');

      return rows.map((row) {
        final data = row.toColumnMap();
        return Product(
          id: data['id'] as String,
          name: data['name'] as String,
          description: data['description'] as String,
          price: data['price'] as int,
          category: data['category'] as String,
          categoryId: data['category_id'] as String,
          imageLabel: data['image_label'] as String,
          accentColor: Color(data['accent_color'] as int),
          imageAsset: data['image_asset'] as String?,
        );
      }).toList();
    } finally {
      await connection.close();
    }
  }
}
