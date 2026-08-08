import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/discount_code.dart';

class DiscountRepository {
  const DiscountRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<DiscountCode>> fetchDiscountCodes() async {
    final connection = await _open();
    try {
      final rows = await connection.execute('''
        SELECT
          id, code, description, discount_type, discount_value,
          minimum_order_value, maximum_discount, usage_limit, used_count,
          start_at, end_at, is_active, created_at, updated_at
        FROM discount_codes
        ORDER BY is_active DESC, end_at ASC, code ASC
      ''');
      return rows
          .map((row) => DiscountCode.fromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<AppliedDiscount> validateCode({
    required String code,
    required int subtotal,
  }) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          SELECT
            id, code, description, discount_type, discount_value,
            minimum_order_value, maximum_discount, usage_limit, used_count,
            start_at, end_at, is_active, created_at, updated_at
          FROM discount_codes
          WHERE code = UPPER(BTRIM(@code))
          LIMIT 1
        '''),
        parameters: {'code': code},
      );
      if (rows.isEmpty) {
        throw const DiscountException('Mã giảm giá không tồn tại.');
      }
      final discount = DiscountCode.fromColumnMap(rows.first.toColumnMap());
      final now = DateTime.now();
      if (!discount.isActive) {
        throw const DiscountException('Mã giảm giá đang tạm tắt.');
      }
      if (now.isBefore(discount.startAt) || now.isAfter(discount.endAt)) {
        throw const DiscountException('Mã giảm giá chưa hoặc đã hết hiệu lực.');
      }
      if (subtotal < discount.minimumOrderValue) {
        throw DiscountException(
          'Đơn hàng cần từ ${discount.minimumOrderValue}đ để dùng mã này.',
        );
      }
      if (!discount.isUsageAvailable) {
        throw const DiscountException('Mã giảm giá đã hết lượt sử dụng.');
      }
      return AppliedDiscount(
        discount: discount,
        amount: discount.calculateDiscount(subtotal),
      );
    } finally {
      await connection.close();
    }
  }

  Future<void> saveDiscountCode(DiscountCode discount) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          INSERT INTO discount_codes (
            id, code, description, discount_type, discount_value,
            minimum_order_value, maximum_discount, usage_limit, used_count,
            start_at, end_at, is_active, updated_at
          )
          VALUES (
            @id, @code, @description, @type, @value,
            @minimumOrder, @maximumDiscount, @usageLimit, @usedCount,
            @startAt, @endAt, @isActive, NOW()
          )
          ON CONFLICT (id) DO UPDATE SET
            code = EXCLUDED.code,
            description = EXCLUDED.description,
            discount_type = EXCLUDED.discount_type,
            discount_value = EXCLUDED.discount_value,
            minimum_order_value = EXCLUDED.minimum_order_value,
            maximum_discount = EXCLUDED.maximum_discount,
            usage_limit = EXCLUDED.usage_limit,
            start_at = EXCLUDED.start_at,
            end_at = EXCLUDED.end_at,
            is_active = EXCLUDED.is_active,
            updated_at = NOW()
        '''),
        parameters: {
          'id': discount.id,
          'code': discount.code,
          'description': discount.description,
          'type': discount.type.databaseValue,
          'value': discount.discountValue,
          'minimumOrder': discount.minimumOrderValue,
          'maximumDiscount': discount.maximumDiscount,
          'usageLimit': discount.usageLimit,
          'usedCount': discount.usedCount,
          'startAt': discount.startAt,
          'endAt': discount.endAt,
          'isActive': discount.isActive,
        },
      );
    } on UniqueViolationException {
      throw const DiscountException('Mã giảm giá đã tồn tại.');
    } finally {
      await connection.close();
    }
  }

  Future<void> setActive({required String id, required bool isActive}) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          UPDATE discount_codes
          SET is_active = @isActive
          WHERE id = @id
          RETURNING id
        '''),
        parameters: {'id': id, 'isActive': isActive},
      );
      if (rows.isEmpty) {
        throw const DiscountException('Không tìm thấy mã giảm giá.');
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

class DiscountException implements Exception {
  const DiscountException(this.message);

  final String message;

  @override
  String toString() => message;
}
