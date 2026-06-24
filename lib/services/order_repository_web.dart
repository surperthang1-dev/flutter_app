import '../models/auth_user.dart';
import '../models/cart_item.dart';

class OrderRepository {
  const OrderRepository({this.config});

  final Object? config;

  Future<String> createOrder({
    required AuthUser? user,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String paymentMethod,
    required int subtotal,
    required int deliveryFee,
    required int total,
    required List<CartItem> items,
    String? note,
  }) {
    throw UnsupportedError(
      'Bản web không thể kết nối PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
    );
  }
}
