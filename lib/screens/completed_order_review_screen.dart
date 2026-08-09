import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/product.dart';
import '../models/order_status.dart';
import '../providers/auth_provider.dart';
import '../services/order_repository.dart';
import '../services/postgres_product_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/product_visual.dart';
import 'product_detail_screen.dart';

class CompletedOrderReviewScreen extends StatefulWidget {
  const CompletedOrderReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CompletedOrderReviewScreen> createState() =>
      _CompletedOrderReviewScreenState();
}

class _CompletedOrderReviewScreenState
    extends State<CompletedOrderReviewScreen> {
  final _orderRepository = const OrderRepository();
  final _productRepository = const PostgresProductRepository();
  Future<_CompletedOrderReviewData>? _future;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.of(context).user;
    if (user == null || user.id == _userId) return;
    _userId = user.id;
    _future = _load(user.id);
  }

  Future<_CompletedOrderReviewData> _load(String userId) async {
    final results = await Future.wait<Object?>([
      _orderRepository.fetchOrderForUser(
        userId: userId,
        orderId: widget.orderId,
      ),
      _productRepository.fetchProducts(),
    ]);
    final order = results[0] as AdminOrder?;
    if (order == null) {
      throw const _CompletedOrderReviewException(
        'Không tìm thấy đơn hàng này.',
      );
    }
    if (order.orderStatus != OrderStatus.completed) {
      throw const _CompletedOrderReviewException(
        'Chỉ có thể đánh giá sau khi đơn hàng đã giao thành công.',
      );
    }
    final products = results[1] as List<Product>;
    return _CompletedOrderReviewData(
      order: order,
      productsById: {for (final product in products) product.id: product},
    );
  }

  Future<void> _refresh() async {
    final userId = AuthScope.of(context).user?.id;
    if (userId == null) return;
    final future = _load(userId);
    setState(() => _future = future);
    await future;
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đánh giá đơn hàng')),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<_CompletedOrderReviewData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ReviewOrderMessage(
                    error: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final data = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: AppColors.success,
                              size: 26,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cảm ơn bạn đã đặt hàng',
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Chạm vào món đã mua để xem chi tiết và viết đánh giá.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Đơn #${data.order.shortId}',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...data.order.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PurchasedProductTile(
                            item: item,
                            product: data.productsById[item.productId],
                            onTap: data.productsById[item.productId] == null
                                ? null
                                : () => _openProduct(
                                    data.productsById[item.productId]!,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CompletedOrderReviewData {
  const _CompletedOrderReviewData({
    required this.order,
    required this.productsById,
  });

  final AdminOrder order;
  final Map<String, Product> productsById;
}

class _CompletedOrderReviewException implements Exception {
  const _CompletedOrderReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PurchasedProductTile extends StatelessWidget {
  const _PurchasedProductTile({
    required this.item,
    required this.product,
    required this.onTap,
  });

  final AdminOrderItem item;
  final Product? product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canReview = product != null;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 64,
                width: 64,
                child: product == null
                    ? const _MissingProductVisual()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ProductVisual(
                          product: product!,
                          height: 64,
                          iconSize: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.quantity} món · Size ${item.size}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      canReview
                          ? 'Chạm để đánh giá sản phẩm'
                          : 'Sản phẩm hiện không còn phục vụ',
                      style: TextStyle(
                        color: canReview
                            ? AppColors.coffee
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                canReview
                    ? Icons.rate_review_rounded
                    : Icons.info_outline_rounded,
                color: canReview ? AppColors.coffee : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingProductVisual extends StatelessWidget {
  const _MissingProductVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mutedSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
    );
  }
}

class _ReviewOrderMessage extends StatelessWidget {
  const _ReviewOrderMessage({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 48,
              color: AppColors.caramel,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
