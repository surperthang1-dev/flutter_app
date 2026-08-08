import '../config/database_config.dart';
import '../models/discount_code.dart';

class DiscountRepository {
  const DiscountRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<DiscountCode>> fetchDiscountCodes() => throw _error();
  Future<AppliedDiscount> validateCode({
    required String code,
    required int subtotal,
  }) => throw _error();
  Future<void> saveDiscountCode(DiscountCode discount) => throw _error();
  Future<void> setActive({required String id, required bool isActive}) =>
      throw _error();

  UnsupportedError _error() => UnsupportedError(
    'Bản Chrome/web không thể quản trị PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
  );
}

class DiscountException implements Exception {
  const DiscountException(this.message);
  final String message;
  @override
  String toString() => message;
}
