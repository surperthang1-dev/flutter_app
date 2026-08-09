import '../config/database_config.dart';
import '../models/user_notification.dart';

class NotificationRepository {
  const NotificationRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<UserNotification>> fetchNotifications(String userId) =>
      throw _webError();

  Future<int> fetchUnreadCount(String userId) => throw _webError();

  Future<void> markRead({required String userId, required int id}) =>
      throw _webError();

  Future<void> markAllRead(String userId) => throw _webError();

  UnsupportedError _webError() {
    return UnsupportedError(
      'Bản Chrome/web không thể đọc thông báo trực tiếp từ PostgreSQL. Hãy chạy app Windows/native.',
    );
  }
}
