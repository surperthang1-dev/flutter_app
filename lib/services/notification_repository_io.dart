import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/user_notification.dart';

class NotificationRepository {
  const NotificationRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<UserNotification>> fetchNotifications(String userId) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          SELECT id, user_id, type, order_id, title, message, is_read, created_at
          FROM user_notifications
          WHERE user_id = CAST(@userId AS UUID)
          ORDER BY created_at DESC, id DESC
          LIMIT 80
        '''),
        parameters: {'userId': userId},
      );
      return rows
          .map((row) => UserNotification.fromColumnMap(row.toColumnMap()))
          .toList();
    } finally {
      await connection.close();
    }
  }

  Future<int> fetchUnreadCount(String userId) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          SELECT COUNT(*)::INTEGER AS unread_count
          FROM user_notifications
          WHERE user_id = CAST(@userId AS UUID)
            AND is_read = FALSE
        '''),
        parameters: {'userId': userId},
      );
      return (rows.first.toColumnMap()['unread_count'] as num).toInt();
    } finally {
      await connection.close();
    }
  }

  Future<void> markRead({required String userId, required int id}) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          UPDATE user_notifications
          SET is_read = TRUE
          WHERE id = @id
            AND user_id = CAST(@userId AS UUID)
        '''),
        parameters: {'id': id, 'userId': userId},
      );
    } finally {
      await connection.close();
    }
  }

  Future<void> markAllRead(String userId) async {
    final connection = await _open();
    try {
      await connection.execute(
        Sql.named('''
          UPDATE user_notifications
          SET is_read = TRUE
          WHERE user_id = CAST(@userId AS UUID)
            AND is_read = FALSE
        '''),
        parameters: {'userId': userId},
      );
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
