import 'package:flutter_app/models/cart_item.dart';
import 'package:flutter_app/models/order_status.dart';
import 'package:flutter_app/models/product.dart';
import 'package:flutter_app/models/user_notification.dart';
import 'package:flutter_app/services/delivery_area_repository.dart';
import 'package:flutter_app/services/notification_repository.dart';
import 'package:flutter_app/services/order_repository.dart';
import 'package:flutter_app/services/postgres_auth_repository.dart';
import 'package:flutter_app/utils/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('Order notification workflow', () {
    final auth = const PostgresAuthRepository();
    final areas = const DeliveryAreaRepository();
    final orders = const OrderRepository();
    final notifications = const NotificationRepository();

    test(
      'notifies user when an order is placed, delivered, and completed',
      () async {
        final suffix = DateTime.now().microsecondsSinceEpoch
            .remainder(100000000)
            .toString()
            .padLeft(8, '0');
        final phone = '09$suffix';
        addTearDown(() => _deleteAccount(phone));
        final area = (await areas.fetchAreas()).first;
        final user = await auth.register(
          fullName: 'Notification Test $suffix',
          phone: phone,
          email: 'notification-$suffix@coffeeviet.local',
          password: 'secret123',
          addressDetail: '99 Đường Thông Báo',
          addressNote: 'Gọi trước khi giao',
          deliveryAreaId: area.id,
        );

        final orderId = await orders.createOrder(
          user: user,
          paymentMethod: 'Tiền mặt khi nhận hàng',
          items: [_cartItem()],
        );
        var items = await notifications.fetchNotifications(user.id);
        expect(
          items.where(
            (item) =>
                item.orderId == orderId &&
                item.type == UserNotificationType.orderCreated,
          ),
          hasLength(1),
        );
        expect(await notifications.fetchUnreadCount(user.id), 1);

        final admin = await auth.login(
          phone: '0999999999',
          password: 'admin123',
        );
        for (final status in [
          OrderStatus.confirmed,
          OrderStatus.preparing,
          OrderStatus.delivering,
          OrderStatus.completed,
        ]) {
          await orders.transitionOrder(
            actor: admin,
            orderId: orderId,
            nextStatus: status,
          );
        }

        items = await notifications.fetchNotifications(user.id);
        expect(
          items.where(
            (item) =>
                item.orderId == orderId &&
                item.type == UserNotificationType.orderDelivering,
          ),
          hasLength(1),
        );
        final completed = items.singleWhere(
          (item) =>
              item.orderId == orderId &&
              item.type == UserNotificationType.orderCompleted,
        );
        expect(completed.isRead, isFalse);
        expect(completed.message, contains('đánh giá'));

        await notifications.markRead(userId: user.id, id: completed.id);
        expect(await notifications.fetchUnreadCount(user.id), 2);
        await notifications.markAllRead(user.id);
        expect(await notifications.fetchUnreadCount(user.id), 0);
      },
    );
  });
}

CartItem _cartItem() {
  return CartItem(
    id: 'notification-item',
    product: const Product(
      id: 'bac-xiu',
      name: 'Bạc xỉu',
      description: 'Sản phẩm kiểm thử thông báo',
      price: 39000,
      category: 'Cà phê',
      categoryId: 'legacy-coffee',
      imageLabel: 'Bạc xỉu',
      accentColor: AppColors.caramel,
    ),
    size: 'M',
    sugar: '70%',
    ice: 'Vừa',
    note: '',
    quantity: 1,
  );
}

Future<void> _deleteAccount(String phone) async {
  final connection = await Connection.open(
    Endpoint(
      host: '127.0.0.1',
      port: 5432,
      database: 'coffee_viet_24h',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  try {
    await connection.runTx((session) async {
      await session.execute(
        Sql.named('''
          DELETE FROM orders
          WHERE user_id = (SELECT id FROM app_users WHERE phone = @phone)
        '''),
        parameters: {'phone': phone},
      );
      await session.execute(
        Sql.named('DELETE FROM app_users WHERE phone = @phone'),
        parameters: {'phone': phone},
      );
    });
  } finally {
    await connection.close();
  }
}
