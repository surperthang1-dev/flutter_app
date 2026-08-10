import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_review.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/product_review_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/option_chip_selector.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // State cấu hình món (size/đường/đá) và state review được tách trên cùng màn chi tiết.
  final _noteController = TextEditingController();
  final _reviewRepository = const ProductReviewRepository();
  String _size = 'M';
  String _sugar = '70%';
  String _ice = 'Vừa';
  int _quantity = 1;
  Future<ProductReviewOverview>? _reviewsFuture;
  String? _reviewViewerId;

  int get _unitPrice {
    // Giá size được tính ở UI để user thấy tổng tạm tính trước khi thêm giỏ.
    final extra = switch (_size) {
      'M' => 5000,
      'L' => 10000,
      _ => 0,
    };
    return widget.product.price + extra;
  }

  int get _total => _unitPrice * _quantity;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewerId = AuthScope.of(context).user?.id;
    if (_reviewsFuture == null || viewerId != _reviewViewerId) {
      _reviewViewerId = viewerId;
      _reviewsFuture = _reviewRepository.fetchOverview(
        productId: widget.product.id,
        viewerUserId: viewerId,
      );
    }
  }

  Future<void> _reloadReviews() async {
    final future = _reviewRepository.fetchOverview(
      productId: widget.product.id,
      viewerUserId: AuthScope.of(context).user?.id,
    );
    setState(() => _reviewsFuture = future);
    await future;
  }

  Future<void> _openReviewComposer(ProductReview? existingReview) async {
    // Bottom sheet cho phép tạo mới hoặc cập nhật review duy nhất của user cho món này.
    final user = AuthScope.of(context).user;
    if (user == null) return;
    final controller = TextEditingController(
      text: existingReview?.comment ?? '',
    );
    var rating = existingReview?.rating ?? 5;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSubmitting = false;
        var didSave = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existingReview == null
                                ? 'Đánh giá ${widget.product.name}'
                                : 'Cập nhật đánh giá',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mỗi tài khoản có một đánh giá cho mỗi sản phẩm. Gửi lại sẽ cập nhật đánh giá cũ.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          tooltip: '$value sao',
                          onPressed: isSubmitting
                              ? null
                              : () => setSheetState(() => rating = value),
                          icon: Icon(
                            value <= rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.caramel,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    Text(
                      '$rating/5 sao',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 600,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Nhận xét của bạn',
                        hintText: 'Hương vị, chất lượng, đóng gói...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: isSubmitting
                          ? 'Đang gửi...'
                          : existingReview == null
                          ? 'Gửi đánh giá'
                          : 'Cập nhật đánh giá',
                      icon: Icons.rate_review_rounded,
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _reviewRepository.submitReview(
                                  user: user,
                                  productId: widget.product.id,
                                  rating: rating,
                                  comment: controller.text,
                                );
                                if (sheetContext.mounted) {
                                  didSave = true;
                                  Navigator.of(sheetContext).pop(true);
                                }
                              } on ProductReviewException catch (error) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(error.message),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không thể gửi đánh giá. Vui lòng thử lại.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                if (sheetContext.mounted && !didSave) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (saved == true && mounted) {
      await _reloadReviews();
    }
  }

  void _addToCart() {
    // CartProvider tự gộp các món có cùng tùy chọn thay vì trùng nhiều dòng.
    CartScope.of(context).addProduct(
      product: widget.product,
      size: _size,
      sugar: _sugar,
      ice: _ice,
      note: _noteController.text,
      quantity: _quantity,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm $_quantity x ${widget.product.name} vào giỏ.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.coffeeDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết món'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 136),
        children: [
          ProductVisual(product: widget.product, height: 260, iconSize: 78),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.product.name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatVnd(_unitPrice),
                style: const TextStyle(
                  color: AppColors.coffee,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OptionChipSelector(
                  label: 'Chọn size',
                  options: const ['S', 'M', 'L'],
                  value: _size,
                  onChanged: (value) => setState(() => _size = value),
                ),
                const SizedBox(height: 18),
                OptionChipSelector(
                  label: 'Lượng đường',
                  options: const ['0%', '30%', '50%', '70%', '100%'],
                  value: _sugar,
                  onChanged: (value) => setState(() => _sugar = value),
                ),
                const SizedBox(height: 18),
                OptionChipSelector(
                  label: 'Lượng đá',
                  options: const ['Ít đá', 'Vừa', 'Nhiều đá'],
                  value: _ice,
                  onChanged: (value) => setState(() => _ice = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho quán',
              hintText: 'Ví dụ: ít sữa, không đá, ghi tên lên ly...',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Số lượng',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                QuantityStepper(
                  value: _quantity,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ReviewSection(
            future: _reviewsFuture!,
            currentUserId: AuthScope.of(context).user?.id,
            onRetry: _reloadReviews,
            onWriteReview: _openReviewComposer,
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng cộng',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatVnd(_total),
                      style: const TextStyle(
                        color: AppColors.coffee,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 176,
                child: PrimaryButton(
                  label: 'Thêm vào giỏ',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: _addToCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.future,
    required this.currentUserId,
    required this.onRetry,
    required this.onWriteReview,
  });

  final Future<ProductReviewOverview> future;
  final String? currentUserId;
  final Future<void> Function() onRetry;
  final ValueChanged<ProductReview?> onWriteReview;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductReviewOverview>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Panel(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa tải được đánh giá sản phẩm.',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tải lại'),
                ),
              ],
            ),
          );
        }

        final overview = snapshot.data!;
        ProductReview? currentReview;
        if (currentUserId != null) {
          for (final review in overview.reviews) {
            if (review.userId == currentUserId) {
              currentReview = review;
              break;
            }
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Đánh giá từ khách hàng',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onWriteReview(currentReview),
                  icon: Icon(
                    currentReview == null
                        ? Icons.rate_review_rounded
                        : Icons.edit_rounded,
                    size: 18,
                  ),
                  label: Text(
                    currentReview == null ? 'Viết đánh giá' : 'Sửa đánh giá',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Panel(
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.caramel.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      overview.reviewCount == 0
                          ? '—'
                          : overview.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.coffee,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StarRow(rating: overview.averageRating),
                        const SizedBox(height: 5),
                        Text(
                          overview.reviewCount == 0
                              ? 'Chưa có đánh giá nào'
                              : '${overview.reviewCount} đánh giá từ khách hàng',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (overview.reviews.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Hãy là người đầu tiên chia sẻ cảm nhận về sản phẩm này.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...overview.reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(review: review),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final initial = review.authorName.trim().isEmpty
        ? 'K'
        : review.authorName.trim().characters.first.toUpperCase();
    final date =
        '${review.updatedAt.day.toString().padLeft(2, '0')}/${review.updatedAt.month.toString().padLeft(2, '0')}/${review.updatedAt.year}';

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.coffeeDark,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.isMine
                          ? '${review.authorName} (Bạn)'
                          : review.authorName,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating.toDouble(), iconSize: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(
              color: AppColors.textDark,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.iconSize = 20});

  final double rating;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index + 1;
        final icon = rating >= threshold
            ? Icons.star_rounded
            : rating > index
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(icon, color: AppColors.caramel, size: iconSize);
      }),
    );
  }
}

// Tải lại review khi đổi user để đánh dấu chính xác 'đánh giá của bạn'.
