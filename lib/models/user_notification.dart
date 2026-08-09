enum UserNotificationType { orderCreated, orderDelivering, orderCompleted }

extension UserNotificationTypeX on UserNotificationType {
  String get databaseValue => switch (this) {
    UserNotificationType.orderCreated => 'order_created',
    UserNotificationType.orderDelivering => 'order_delivering',
    UserNotificationType.orderCompleted => 'order_completed',
  };

  static UserNotificationType fromDatabase(String value) {
    return switch (value) {
      'order_delivering' => UserNotificationType.orderDelivering,
      'order_completed' => UserNotificationType.orderCompleted,
      _ => UserNotificationType.orderCreated,
    };
  }
}

class UserNotification {
  const UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.orderId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotification.fromColumnMap(Map<String, dynamic> data) {
    return UserNotification(
      id: (data['id'] as num).toInt(),
      userId: data['user_id'].toString(),
      type: UserNotificationTypeX.fromDatabase(data['type'] as String),
      orderId: data['order_id'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      isRead: data['is_read'] as bool,
      createdAt: data['created_at'] as DateTime,
    );
  }

  final int id;
  final String userId;
  final UserNotificationType type;
  final String orderId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
}
