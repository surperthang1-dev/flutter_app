class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.isMine,
  });

  factory ProductReview.fromColumnMap(Map<String, dynamic> data) {
    return ProductReview(
      id: (data['id'] as num).toInt(),
      productId: data['product_id'] as String,
      userId: data['user_id'].toString(),
      authorName: data['author_name'] as String,
      rating: (data['rating'] as num).toInt(),
      comment: data['comment'] as String,
      createdAt: data['created_at'] as DateTime,
      updatedAt: data['updated_at'] as DateTime,
      isMine: data['is_mine'] as bool? ?? false,
    );
  }

  final int id;
  final String productId;
  final String userId;
  final String authorName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMine;
}

class ProductReviewOverview {
  const ProductReviewOverview({
    required this.averageRating,
    required this.reviewCount,
    required this.reviews,
  });

  final double averageRating;
  final int reviewCount;
  final List<ProductReview> reviews;

  ProductReview? get currentUserReview {
    for (final review in reviews) {
      if (review.isMine) return review;
    }
    return null;
  }
}
