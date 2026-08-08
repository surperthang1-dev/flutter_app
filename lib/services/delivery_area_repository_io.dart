import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/delivery_area.dart';

class DeliveryAreaRepository {
  const DeliveryAreaRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<DeliveryArea>> fetchAreas({bool includeInactive = false}) async {
    final connection = await _open();
    try {
      final rows = await connection.execute('''
        SELECT id, name, shipping_fee, is_active, created_at, updated_at
        FROM delivery_areas
        ${includeInactive ? '' : 'WHERE is_active = TRUE'}
        ORDER BY name ASC
      ''');
      return rows
          .map((row) => DeliveryArea.fromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<void> updateArea({
    required String id,
    required int shippingFee,
    required bool isActive,
  }) async {
    if (shippingFee < 0) {
      throw const DeliveryAreaException('Phí giao hàng không thể là số âm.');
    }
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          UPDATE delivery_areas
          SET shipping_fee = @shippingFee,
              is_active = @isActive,
              updated_at = NOW()
          WHERE id = @id
          RETURNING id
        '''),
        parameters: {
          'id': id,
          'shippingFee': shippingFee,
          'isActive': isActive,
        },
      );
      if (rows.isEmpty) {
        throw const DeliveryAreaException('Không tìm thấy khu vực giao hàng.');
      }
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

class DeliveryAreaException implements Exception {
  const DeliveryAreaException(this.message);

  final String message;

  @override
  String toString() => message;
}
