import '../config/database_config.dart';
import '../models/admin_order.dart';
import '../models/product.dart';

class AdminSummary {
  const AdminSummary({
    required this.productCount,
    required this.userCount,
    required this.adminCount,
    required this.menuValue,
    required this.averagePrice,
    required this.orderCount,
    required this.revenue,
    required this.todayRevenue,
  });

  final int productCount;
  final int userCount;
  final int adminCount;
  final int menuValue;
  final int averagePrice;
  final int orderCount;
  final int revenue;
  final int todayRevenue;
}

class AdminRepository {
  const AdminRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<AdminSummary> fetchSummary() => throw _webError();
  Future<List<Product>> fetchProducts() => throw _webError();
  Future<List<AdminOrder>> fetchOrders() => throw _webError();
  Future<void> saveProduct(Product product) => throw _webError();
  Future<void> deleteProduct(String id) => throw _webError();
  Future<String?> pickAndStoreProductImage(String idHint) => throw _webError();
  Future<String> exportInvoice([String? orderId]) => throw _webError();
  Future<String> exportMenuInvoice() => throw _webError();

  UnsupportedError _webError() {
    return UnsupportedError(
      'Bản Chrome/web không thể quản trị PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
    );
  }
}
