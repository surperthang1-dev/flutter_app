import '../config/database_config.dart';
import '../models/product.dart';

class PostgresProductRepository {
  const PostgresProductRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<Product>> fetchProducts() async {
    throw UnsupportedError(
      'Bản Chrome/web không thể đọc PostgreSQL trực tiếp.',
    );
  }
}
