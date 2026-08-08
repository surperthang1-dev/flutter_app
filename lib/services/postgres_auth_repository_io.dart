import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostgresAuthRepository {
  const PostgresAuthRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<AuthUser> login({
    required String phone,
    required String password,
  }) async {
    final connection = await _open();

    try {
      final rows = await connection.execute(
        Sql.named('''
          SELECT
            users.id,
            users.full_name,
            users.phone,
            users.email,
            users.role,
            users.address,
            users.address_detail,
            users.address_note,
            users.delivery_area_id,
            areas.name AS delivery_area_name
          FROM app_users users
          LEFT JOIN delivery_areas areas ON areas.id = users.delivery_area_id
          WHERE users.phone = @phone
            AND users.password_hash = encode(digest(@password, 'sha256'), 'hex')
          LIMIT 1
        '''),
        parameters: {'phone': phone, 'password': password},
      );

      if (rows.isEmpty) {
        throw const AuthException('Số điện thoại hoặc mật khẩu không đúng.');
      }

      return AuthUser.fromColumnMap(rows.first.toColumnMap());
    } finally {
      await connection.close();
    }
  }

  Future<AuthUser> register({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    required String addressDetail,
    required String deliveryAreaId,
    String? addressNote,
  }) async {
    final connection = await _open();

    try {
      final rows = await connection.execute(
        Sql.named('''
          INSERT INTO app_users (
            full_name,
            phone,
            email,
            role,
            password_hash,
            address,
            address_detail,
            address_note,
            delivery_area_id
          )
          SELECT
            @fullName,
            @phone,
            NULLIF(@email, ''),
            0,
            encode(digest(@password, 'sha256'), 'hex'),
            NULLIF(@addressDetail, ''),
            NULLIF(@addressDetail, ''),
            NULLIF(@addressNote, ''),
            @deliveryAreaId
          WHERE EXISTS (
            SELECT 1
            FROM delivery_areas
            WHERE id = @deliveryAreaId
              AND is_active = TRUE
          )
          RETURNING
            id,
            full_name,
            phone,
            email,
            role,
            address,
            address_detail,
            address_note,
            delivery_area_id,
            (
              SELECT name
              FROM delivery_areas
              WHERE id = app_users.delivery_area_id
            ) AS delivery_area_name
        '''),
        parameters: {
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': email ?? '',
          'password': password,
          'addressDetail': addressDetail.trim(),
          'addressNote': addressNote?.trim() ?? '',
          'deliveryAreaId': deliveryAreaId,
        },
      );

      if (rows.isEmpty) {
        throw const AuthException(
          'Khu vực giao hàng đã tạm ngừng. Vui lòng chọn khu vực khác.',
        );
      }

      return AuthUser.fromColumnMap(rows.first.toColumnMap());
    } on UniqueViolationException {
      throw const AuthException('Số điện thoại hoặc email đã được sử dụng.');
    } finally {
      await connection.close();
    }
  }

  Future<void> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    final connection = await _open();

    try {
      final rows = await connection.execute(
        Sql.named('''
          UPDATE app_users
          SET password_hash = encode(digest(@password, 'sha256'), 'hex'),
              updated_at = NOW()
          WHERE phone = @phone
          RETURNING id
        '''),
        parameters: {'phone': phone, 'password': newPassword},
      );

      if (rows.isEmpty) {
        throw const AuthException(
          'Không tìm thấy tài khoản với số điện thoại này.',
        );
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
