import '../config/database_config.dart';
import '../models/delivery_area.dart';

class DeliveryAreaRepository {
  const DeliveryAreaRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<DeliveryArea>> fetchAreas({bool includeInactive = false}) {
    throw _webError();
  }

  Future<void> updateArea({
    required String id,
    required int shippingFee,
    required bool isActive,
  }) {
    throw _webError();
  }

  UnsupportedError _webError() {
    return UnsupportedError(
      'Bản web không thể kết nối PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
    );
  }
}

class DeliveryAreaException implements Exception {
  const DeliveryAreaException(this.message);

  final String message;

  @override
  String toString() => message;
}
