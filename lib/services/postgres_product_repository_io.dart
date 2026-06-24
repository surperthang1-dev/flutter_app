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
          id,
          name,
          description,
          price,
          category,
          image_label,
          accent_color,
          image_asset
        FROM products
        WHERE is_active = TRUE
        ORDER BY sort_order ASC, name ASC
        ''');

      return rows.map((row) {
        final data = row.toColumnMap();
        return Product(
          id: data['id'] as String,
          name: data['name'] as String,
          description: data['description'] as String,
          price: data['price'] as int,
          category: data['category'] as String,
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
