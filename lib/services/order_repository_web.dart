import '../config/database_config.dart';
import '../models/admin_order.dart';
import '../models/auth_user.dart';
import '../models/cart_item.dart';
import '../models/checkout_snapshot.dart';
import '../models/order_status.dart';

class OrderRepository {
  const OrderRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<CheckoutSnapshot> fetchCheckoutSnapshot(AuthUser user) =>
      throw _webError();

  Future<String> createOrder({
    required AuthUser user,
    required String paymentMethod,
    required List<CartItem> items,
    String? note,
  }) => throw _webError();

  Future<List<AdminOrder>> fetchOrdersForUser(String userId) =>
      throw _webError();

  Future<AdminOrder?> fetchOrderForUser({
    required String userId,
    required String orderId,
  }) => throw _webError();

  Future<List<AdminOrder>> fetchAllOrders() => throw _webError();

  Future<void> transitionOrder({
    required AuthUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? cancelReason,
  }) => throw _webError();

  UnsupportedError _webError() {
    return UnsupportedError(
      'Bản web không thể kết nối PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
    );
  }
}

class OrderException implements Exception {
  const OrderException(this.message);

  final String message;

  @override
  String toString() => message;
}
