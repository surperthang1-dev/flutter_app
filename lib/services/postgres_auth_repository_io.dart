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
            users.is_active,
            users.address,
            users.address_detail,
            users.address_note,
            users.delivery_area_id,
            users.created_at,
            users.updated_at,
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

      final data = rows.first.toColumnMap();
      if ((data['is_active'] as bool?) == false) {
        throw const AuthException(
          'Tài khoản đã bị khóa. Vui lòng liên hệ cửa hàng.',
        );
      }

      return AuthUser.fromColumnMap(data);
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
            is_active,
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
            TRUE,
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
            is_active,
            address,
            address_detail,
            address_note,
            delivery_area_id,
            created_at,
            updated_at,
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

  /// Updates the information used for delivery and contact. Changing a phone
  /// number is a sensitive operation, so the current password is required for
  /// that specific change.
  Future<AuthUser> updateProfile({
    required AuthUser user,
    required String fullName,
    required String phone,
    String? email,
    required String addressDetail,
    required String addressNote,
    required String deliveryAreaId,
    String currentPassword = '',
  }) async {
    final normalizedPhone = phone.trim();
    final requiresPassword = normalizedPhone != user.phone;
    if (requiresPassword && currentPassword.isEmpty) {
      throw const AuthException(
        'Vui lòng nhập mật khẩu hiện tại để đổi số điện thoại.',
      );
    }

    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          WITH updated AS (
            UPDATE app_users AS users
            SET
              full_name = @fullName,
              phone = @phone,
              email = NULLIF(@email, ''),
              address = NULLIF(@addressDetail, ''),
              address_detail = NULLIF(@addressDetail, ''),
              address_note = NULLIF(@addressNote, ''),
              delivery_area_id = @deliveryAreaId,
              updated_at = NOW()
            WHERE users.id = @userId
              AND users.is_active = TRUE
              AND (
                @requiresPassword = FALSE
                OR users.password_hash = encode(
                  digest(@currentPassword, 'sha256'),
                  'hex'
                )
              )
            RETURNING users.*
          )
          SELECT
            updated.id,
            updated.full_name,
            updated.phone,
            updated.email,
            updated.role,
            updated.is_active,
            updated.address,
            updated.address_detail,
            updated.address_note,
            updated.delivery_area_id,
            updated.created_at,
            updated.updated_at,
            areas.name AS delivery_area_name
          FROM updated
          LEFT JOIN delivery_areas areas ON areas.id = updated.delivery_area_id
        '''),
        parameters: {
          'userId': user.id,
          'fullName': fullName.trim(),
          'phone': normalizedPhone,
          'email': email?.trim() ?? '',
          'addressDetail': addressDetail.trim(),
          'addressNote': addressNote.trim(),
          'deliveryAreaId': deliveryAreaId,
          'requiresPassword': requiresPassword,
          'currentPassword': currentPassword,
        },
      );

      if (rows.isEmpty) {
        throw AuthException(
          requiresPassword
              ? 'Mật khẩu hiện tại không đúng hoặc tài khoản đã bị khóa.'
              : 'Không thể cập nhật tài khoản. Vui lòng đăng nhập lại.',
        );
      }

      return AuthUser.fromColumnMap(rows.first.toColumnMap());
    } on UniqueViolationException {
      throw const AuthException('Số điện thoại hoặc email đã được sử dụng.');
    } finally {
      await connection.close();
    }
  }

  Future<void> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const AuthException('Vui lòng nhập mật khẩu hiện tại.');
    }
    if (currentPassword == newPassword) {
      throw const AuthException('Mật khẩu mới cần khác mật khẩu hiện tại.');
    }

    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          UPDATE app_users
          SET
            password_hash = encode(digest(@newPassword, 'sha256'), 'hex'),
            updated_at = NOW()
          WHERE id = @userId
            AND is_active = TRUE
            AND password_hash = encode(digest(@currentPassword, 'sha256'), 'hex')
          RETURNING id
        '''),
        parameters: {
          'userId': user.id,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (rows.isEmpty) {
        throw const AuthException(
          'Mật khẩu hiện tại không đúng hoặc tài khoản đã bị khóa.',
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
