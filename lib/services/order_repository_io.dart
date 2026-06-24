import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/auth_user.dart';
import '../models/cart_item.dart';

class OrderRepository {
  const OrderRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<String> createOrder({
    required AuthUser? user,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String paymentMethod,
    required int subtotal,
    required int deliveryFee,
    required int total,
    required List<CartItem> items,
    String? note,
  }) async {
    if (items.isEmpty) {
      throw const OrderException('Giỏ hàng đang trống.');
    }

    final orderId = 'CFV-${DateTime.now().millisecondsSinceEpoch}';
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          INSERT INTO orders (
            id,
            user_id,
            customer_name,
            customer_phone,
            delivery_address,
            payment_method,
            subtotal,
            delivery_fee,
            total,
            status,
            note
          )
          VALUES (
            @id,
            CAST(NULLIF(@userId, '') AS UUID),
            @customerName,
            @customerPhone,
            @deliveryAddress,
            @paymentMethod,
            @subtotal,
            @deliveryFee,
            @total,
            'pending',
            NULLIF(@note, '')
          )
        '''),
        parameters: {
          'id': orderId,
          'userId': user?.id ?? '',
          'customerName': customerName.trim(),
          'customerPhone': customerPhone.trim(),
          'deliveryAddress': deliveryAddress.trim(),
          'paymentMethod': paymentMethod,
          'subtotal': subtotal,
          'deliveryFee': deliveryFee,
          'total': total,
          'note': note?.trim() ?? '',
        },
      );

      for (final item in items) {
        await connection.execute(
          Sql.named('''
            INSERT INTO order_items (
              order_id,
              product_id,
              product_name,
              unit_price,
              quantity,
              size,
              sugar,
              ice,
              note,
              line_total
            )
            VALUES (
              @orderId,
              @productId,
              @productName,
              @unitPrice,
              @quantity,
              @size,
              @sugar,
              @ice,
              NULLIF(@note, ''),
              @lineTotal
            )
          '''),
          parameters: {
            'orderId': orderId,
            'productId': item.product.id,
            'productName': item.product.name,
            'unitPrice': item.unitPrice,
            'quantity': item.quantity,
            'size': item.size,
            'sugar': item.sugar,
            'ice': item.ice,
            'note': item.note,
            'lineTotal': item.totalPrice,
          },
        );
      }

      return orderId;
    } finally {
      await connection.close();
    }
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

class OrderException implements Exception {
  const OrderException(this.message);

  final String message;

  @override
  String toString() => message;
}
