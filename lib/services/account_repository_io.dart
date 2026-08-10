import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/admin_account.dart';

class AccountRepository {
  const AccountRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<AdminAccount>> fetchAccounts() async {
    // Admin xem vai trò, trạng thái hoạt động, khu vực và số đơn của từng tài khoản.
    final connection = await _open();
    try {
      final rows = await connection.execute('''
        SELECT
          users.id,
          users.full_name,
          users.phone,
          users.email,
          users.role,
          users.is_active,
          areas.name AS delivery_area_name,
          users.created_at,
          users.updated_at,
          COUNT(orders.id)::int AS order_count
        FROM app_users users
        LEFT JOIN delivery_areas areas ON areas.id = users.delivery_area_id
        LEFT JOIN orders ON orders.user_id = users.id
        GROUP BY users.id, areas.name
        ORDER BY users.role DESC, users.is_active DESC, users.created_at DESC
      ''');
      return rows
          .map((row) => AdminAccount.fromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<void> setAccountActive({
    required String actorId,
    required String accountId,
    required bool isActive,
  }) async {
    // Bảo vệ: không tự khóa chính mình và không khóa admin active cuối cùng.
    if (actorId == accountId) {
      throw const AccountException(
        'Không thể khóa chính tài khoản đang đăng nhập.',
      );
    }
    final connection = await _open();
    try {
      await connection.runTx((session) async {
        final rows = await session.execute(
          Sql.named('''
            SELECT id, role, is_active
            FROM app_users
            WHERE id = CAST(@id AS UUID)
            FOR UPDATE
          '''),
          parameters: {'id': accountId},
        );
        if (rows.isEmpty) {
          throw const AccountException('Không tìm thấy tài khoản.');
        }
        final account = rows.first.toColumnMap();
        if ((account['role'] as int) == 1 &&
            account['is_active'] as bool &&
            !isActive) {
          final admins = await session.execute('''
            SELECT COUNT(*)::int AS count
            FROM app_users
            WHERE role = 1 AND is_active = TRUE
          ''');
          if ((admins.first.toColumnMap()['count'] as int) <= 1) {
            throw const AccountException(
              'Không thể khóa quản trị viên cuối cùng.',
            );
          }
        }
        await session.execute(
          Sql.named('''
            UPDATE app_users
            SET is_active = @isActive
            WHERE id = CAST(@id AS UUID)
          '''),
          parameters: {'id': accountId, 'isActive': isActive},
        );
      });
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

class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}
