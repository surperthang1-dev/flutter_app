import '../config/database_config.dart';
import '../models/auth_user.dart';
import '../models/product_review.dart';

class ProductReviewRepository {
  const ProductReviewRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<ProductReviewOverview> fetchOverview({
    required String productId,
    String? viewerUserId,
  }) {
    throw const ProductReviewException(
      'Bản Chrome/web không thể tải đánh giá trực tiếp từ PostgreSQL. Hãy chạy app Windows/native.',
    );
  }

  Future<void> submitReview({
    required AuthUser user,
    required String productId,
    required int rating,
    required String comment,
  }) {
    throw const ProductReviewException(
      'Bản Chrome/web không thể gửi đánh giá trực tiếp tới PostgreSQL. Hãy chạy app Windows/native.',
    );
  }

  Future<void> deleteReview({required int reviewId, required AuthUser user}) {
    throw const ProductReviewException(
      'Bản Chrome/web không thể xóa đánh giá trực tiếp từ PostgreSQL. Hãy chạy app Windows/native.',
    );
  }
}

class ProductReviewException implements Exception {
  const ProductReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}
