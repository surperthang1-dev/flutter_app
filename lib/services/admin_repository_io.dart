import 'dart:io';

import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/admin_order.dart';
import '../models/product.dart';
import 'order_repository.dart';

class AdminSummary {
  const AdminSummary({
    required this.productCount,
    required this.userCount,
    required this.adminCount,
    required this.menuValue,
    required this.averagePrice,
    required this.orderCount,
    required this.revenue,
    required this.todayRevenue,
  });

  final int productCount;
  final int userCount;
  final int adminCount;
  final int menuValue;
  final int averagePrice;
  final int orderCount;
  final int revenue;
  final int todayRevenue;
}

class AdminRepository {
  const AdminRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<AdminSummary> fetchSummary() async {
    final connection = await _open();
    try {
      final rows = await connection.execute('''
        SELECT
          (SELECT COUNT(*)::int FROM products WHERE is_active = TRUE) AS product_count,
          (SELECT COUNT(*)::int FROM app_users WHERE role = 0) AS user_count,
          (SELECT COUNT(*)::int FROM app_users WHERE role = 1) AS admin_count,
          COALESCE((SELECT SUM(price)::int FROM products WHERE is_active = TRUE), 0) AS menu_value,
          COALESCE((SELECT AVG(price)::int FROM products WHERE is_active = TRUE), 0) AS average_price,
          COALESCE((SELECT COUNT(*)::int FROM orders), 0) AS order_count,
          COALESCE((SELECT SUM(total)::int FROM orders), 0) AS revenue,
          COALESCE((SELECT SUM(total)::int FROM orders WHERE created_at::date = CURRENT_DATE), 0) AS today_revenue
      ''');
      final data = rows.first.toColumnMap();
      return AdminSummary(
        productCount: data['product_count'] as int,
        userCount: data['user_count'] as int,
        adminCount: data['admin_count'] as int,
        menuValue: data['menu_value'] as int,
        averagePrice: data['average_price'] as int,
        orderCount: data['order_count'] as int,
        revenue: data['revenue'] as int,
        todayRevenue: data['today_revenue'] as int,
      );
    } finally {
      await connection.close();
    }
  }

  Future<List<AdminOrder>> fetchOrders() async {
    return OrderRepository(config: config).fetchAllOrders();
  }

  Future<List<Product>> fetchProducts() async {
    final connection = await _open();
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
        ORDER BY products.sort_order ASC, products.name ASC
      ''');
      return rows
          .map((row) => _productFromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<void> saveProduct(Product product) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          INSERT INTO products (
            id,
            name,
            description,
            price,
            category,
            category_id,
            image_label,
            accent_color,
            image_asset,
            is_active,
            updated_at
          )
          VALUES (
            @id,
            @name,
            @description,
            @price,
            @category,
            @categoryId,
            @imageLabel,
            @accentColor,
            NULLIF(@imageAsset, ''),
            TRUE,
            NOW()
          )
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            price = EXCLUDED.price,
            category = EXCLUDED.category,
            category_id = EXCLUDED.category_id,
            image_label = EXCLUDED.image_label,
            accent_color = EXCLUDED.accent_color,
            image_asset = EXCLUDED.image_asset,
            is_active = TRUE,
            updated_at = NOW()
        '''),
        parameters: {
          'id': product.id,
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'category': product.category,
          'categoryId': product.categoryId,
          'imageLabel': product.imageLabel,
          'accentColor': product.accentColor.toARGB32(),
          'imageAsset': product.imageAsset ?? '',
        },
      );
    } finally {
      await connection.close();
    }
  }

  Future<void> deleteProduct(String id) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          DELETE FROM products
          WHERE id = @id
        '''),
        parameters: {'id': id},
      );
    } finally {
      await connection.close();
    }
  }

  Future<String?> pickAndStoreProductImage(String idHint) async {
    final selectedPath = await _pickImagePath();
    if (selectedPath == null || selectedPath.isEmpty) return null;

    final source = File(selectedPath);
    if (!source.existsSync()) return null;

    final extension = source.uri.pathSegments.last
        .split('.')
        .last
        .toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension)) {
      throw const FileSystemException('Định dạng ảnh chưa được hỗ trợ');
    }

    final uploadDir = Directory('uploads/products');
    if (!uploadDir.existsSync()) {
      uploadDir.createSync(recursive: true);
    }

    final safeId = _slug(idHint.isEmpty ? 'product' : idHint);
    final destination = File(
      '${uploadDir.path}${Platform.pathSeparator}$safeId-${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await source.copy(destination.path);
    return destination.absolute.path;
  }

  Future<String> exportInvoice([String? orderId]) async {
    final orders = await fetchOrders();
    AdminOrder? order = orders.isEmpty ? null : orders.first;
    if (orderId != null) {
      order = null;
      for (final item in orders) {
        if (item.id == orderId) {
          order = item;
          break;
        }
      }
    }
    final now = DateTime.now();
    final buffer = StringBuffer()
      ..writeln('CA PHE VIET 24H')
      ..writeln('HOA DON BAN HANG')
      ..writeln('Thoi gian: $now')
      ..writeln('----------------------------------------');

    if (order == null) {
      buffer.writeln('Chua co don hang nao de xuat hoa don.');
    } else {
      buffer
        ..writeln('Ma don: ${order.id}')
        ..writeln('Khach hang: ${order.customerName}')
        ..writeln('Dien thoai: ${order.customerPhone}')
        ..writeln('Dia chi: ${order.deliveryAddress}')
        ..writeln('Thanh toan: ${order.paymentMethod}')
        ..writeln('----------------------------------------');
      for (final item in order.items) {
        buffer.writeln(
          '${item.productName} x${item.quantity} | ${item.size} | ${item.lineTotal} VND',
        );
      }
      buffer
        ..writeln('----------------------------------------')
        ..writeln('Tam tinh: ${order.subtotal} VND')
        ..writeln('Phi giao hang: ${order.deliveryFee} VND')
        ..writeln('Tong thanh toan: ${order.total} VND');
    }

    final file = File('hoa-don-${now.millisecondsSinceEpoch}.txt');
    await file.writeAsString(buffer.toString());
    return file.absolute.path;
  }

  Future<String> exportMenuInvoice() async {
    final products = await fetchProducts();
    final now = DateTime.now();
    final total = products.fold<int>(0, (sum, product) => sum + product.price);
    final buffer = StringBuffer()
      ..writeln('CA PHE VIET 24H')
      ..writeln('BANG GIA MENU')
      ..writeln('Thoi gian: $now')
      ..writeln('----------------------------------------');

    for (final product in products) {
      buffer.writeln(
        '${product.name} | ${product.category} | ${product.price} VND',
      );
    }

    buffer
      ..writeln('----------------------------------------')
      ..writeln('Tong gia tri menu: $total VND');

    final file = File('bang-gia-menu-${now.millisecondsSinceEpoch}.txt');
    await file.writeAsString(buffer.toString());
    return file.absolute.path;
  }

  Product _productFromColumnMap(Map<String, dynamic> data) {
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
  }

  Future<String?> _pickImagePath() async {
    final script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Chon anh san pham'
$dialog.Filter = 'Image files (*.png;*.jpg;*.jpeg;*.webp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.gif'
$dialog.Multiselect = $false
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  Write-Output $dialog.FileName
}
''';

    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-STA',
      '-Command',
      script,
    ]);

    if (result.exitCode != 0) return null;
    final output = result.stdout.toString().trim();
    return output.isEmpty ? null : output.split('\n').last.trim();
  }

  String _slug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<Connection> _open() {
    return Connection.open(
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
}
