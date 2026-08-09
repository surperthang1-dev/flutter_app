import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/auth_user.dart';
import '../models/product_review.dart';

class ProductReviewRepository {
  const ProductReviewRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<ProductReviewOverview> fetchOverview({
    required String productId,
    String? viewerUserId,
  }) async {
    final connection = await _open();
    try {
      final summaryRows = await connection.execute(
        Sql.named('''
          SELECT
            COALESCE(AVG(rating), 0)::DOUBLE PRECISION AS average_rating,
            COUNT(*)::INTEGER AS review_count
          FROM product_reviews
          WHERE product_id = @productId
            AND is_visible = TRUE
        '''),
        parameters: {'productId': productId},
      );
      final summary = summaryRows.first.toColumnMap();
      final reviewRows = await connection.execute(
        Sql.named('''
          SELECT
            reviews.id,
            reviews.product_id,
            reviews.user_id,
            users.full_name AS author_name,
            reviews.rating,
            reviews.comment,
            reviews.created_at,
            reviews.updated_at,
            (
              @viewerUserId <> ''
              AND reviews.user_id::TEXT = @viewerUserId
            ) AS is_mine
          FROM product_reviews reviews
          INNER JOIN app_users users ON users.id = reviews.user_id
          WHERE reviews.product_id = @productId
            AND reviews.is_visible = TRUE
          ORDER BY reviews.updated_at DESC, reviews.id DESC
        '''),
        parameters: {
          'productId': productId,
          'viewerUserId': viewerUserId ?? '',
        },
      );

      return ProductReviewOverview(
        averageRating: (summary['average_rating'] as num).toDouble(),
        reviewCount: (summary['review_count'] as num).toInt(),
        reviews: reviewRows
            .map((row) => ProductReview.fromColumnMap(row.toColumnMap()))
            .toList(),
      );
    } finally {
      await connection.close();
    }
  }

  Future<void> submitReview({
    required AuthUser user,
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final normalizedComment = comment.trim();
    if (rating < 1 || rating > 5) {
      throw const ProductReviewException('Vui lòng chọn từ 1 đến 5 sao.');
    }
    if (normalizedComment.length < 2) {
      throw const ProductReviewException(
        'Vui lòng viết nhận xét ít nhất 2 ký tự.',
      );
    }
    if (normalizedComment.length > 600) {
      throw const ProductReviewException(
        'Nhận xét không được vượt quá 600 ký tự.',
      );
    }

    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          INSERT INTO product_reviews (
            product_id,
            user_id,
            rating,
            comment,
            is_visible
          )
          SELECT @productId, @userId, @rating, @comment, TRUE
          WHERE EXISTS (
            SELECT 1 FROM app_users WHERE id = @userId AND is_active = TRUE
          )
          ON CONFLICT (product_id, user_id) DO UPDATE
          SET
            rating = EXCLUDED.rating,
            comment = EXCLUDED.comment,
            is_visible = TRUE,
            updated_at = NOW()
          RETURNING id
        '''),
        parameters: {
          'productId': productId,
          'userId': user.id,
          'rating': rating,
          'comment': normalizedComment,
        },
      );
      if (rows.isEmpty) {
        throw const ProductReviewException(
          'Tài khoản không còn hoạt động. Vui lòng đăng nhập lại.',
        );
      }
    } on ServerException catch (error) {
      throw ProductReviewException(_messageFromDatabase(error));
    } finally {
      await connection.close();
    }
  }

  Future<void> deleteReview({
    required int reviewId,
    required AuthUser user,
  }) async {
    final connection = await _open();
    try {
      final rows = await connection.execute(
        Sql.named('''
          DELETE FROM product_reviews
          WHERE id = @reviewId
            AND user_id = @userId
          RETURNING id
        '''),
        parameters: {'reviewId': reviewId, 'userId': user.id},
      );
      if (rows.isEmpty) {
        throw const ProductReviewException(
          'Không tìm thấy đánh giá của bạn để xóa.',
        );
      }
    } finally {
      await connection.close();
    }
  }

  String _messageFromDatabase(ServerException error) {
    final message = error.message.trim();
    return message.isEmpty
        ? 'Không thể gửi đánh giá. Vui lòng thử lại.'
        : message;
  }

  Future<Connection> _open() {
    return Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username,
        password: config.password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
  }
}

class ProductReviewException implements Exception {
  const ProductReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}
