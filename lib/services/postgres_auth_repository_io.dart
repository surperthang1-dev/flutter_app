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
          SELECT id, full_name, phone, email, role, address
          FROM app_users
          WHERE phone = @phone
            AND password_hash = encode(digest(@password, 'sha256'), 'hex')
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
    String? address,
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
            address
          )
          VALUES (
            @fullName,
            @phone,
            NULLIF(@email, ''),
            0,
            encode(digest(@password, 'sha256'), 'hex'),
            NULLIF(@address, '')
          )
          RETURNING id, full_name, phone, email, role, address
        '''),
        parameters: {
          'fullName': fullName,
          'phone': phone,
          'email': email ?? '',
          'password': password,
          'address': address ?? '',
        },
      );

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
