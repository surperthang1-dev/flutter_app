import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/order_status.dart';
import '../providers/auth_provider.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/order_timeline.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    this.showAppBar = false,
    required this.orderId,
  });

  final bool showAppBar;
  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _repository = const OrderRepository();
  Future<AdminOrder?>? _future;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.of(context).user;
    if (user == null || user.id == _userId) return;
    _userId = user.id;
    _future = _repository.fetchOrderForUser(
      userId: user.id,
      orderId: widget.orderId,
    );
  }

  Future<void> _refresh() async {
    final user = AuthScope.of(context).user;
    if (user == null) return;
    setState(() {
      _future = _repository.fetchOrderForUser(
        userId: user.id,
        orderId: widget.orderId,
      );
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final content = _future == null
        ? const Center(child: CircularProgressIndicator())
        : FutureBuilder<AdminOrder?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _TrackingMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Không thể tải đơn hàng',
                  body: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              final order = snapshot.data;
              if (order == null) {
                return _TrackingMessage(
                  icon: Icons.receipt_long_outlined,
                  title: 'Không tìm thấy đơn hàng',
                  body: 'Đơn hàng có thể không thuộc tài khoản hiện tại.',
                  onRetry: _refresh,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    _OrderHeader(order: order),
                    const SizedBox(height: 20),
                    _OrderItemsCard(order: order),
                    const SizedBox(height: 20),
                    const Text(
                      'Trạng thái đơn hàng',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OrderTimeline(order: order),
                  ],
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        leading: widget.showAppBar
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: content,
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.cancelReason?.trim().isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mã đơn hàng',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${order.shortId}',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(order: order),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.border),
          ),
          _InfoLine(Icons.location_on_outlined, order.deliveryAddress),
          if (order.deliveryAreaName?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _InfoLine(Icons.local_shipping_outlined, order.deliveryAreaName!),
          ],
          const SizedBox(height: 12),
          _MoneyLine('Tiền sản phẩm', order.subtotal),
          const SizedBox(height: 6),
          _MoneyLine('Phí giao hàng', order.deliveryFee),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.border),
          ),
          _MoneyLine('Tổng thanh toán', order.total, highlight: true),
          if (cancelled) ...[
            const SizedBox(height: 14),
            Text(
              'Lý do hủy: ${order.cancelReason}',
              style: TextStyle(color: Colors.red.shade700, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sản phẩm',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 10),
        ...order.items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.quantity} × ${item.productName}',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item.size} · đường ${item.sugar} · đá ${item.ice}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatVnd(item.lineTotal),
                  style: const TextStyle(
                    color: AppColors.coffee,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.orderStatus) {
      _ when order.orderStatus.name == 'cancelled' => Colors.red.shade700,
      _ when order.orderStatus.name == 'completed' => AppColors.success,
      _ when order.orderStatus.name == 'pending' => AppColors.caramel,
      _ => AppColors.coffee,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        order.orderStatus.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.caramel),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
      ),
    ],
  );
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine(this.label, this.value, {this.highlight = false});

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: highlight ? AppColors.textDark : AppColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        formatVnd(value),
        style: TextStyle(
          color: highlight ? AppColors.caramel : AppColors.textDark,
          fontWeight: FontWeight.w900,
          fontSize: highlight ? 18 : 14,
        ),
      ),
    ],
  );
}

class _TrackingMessage extends StatelessWidget {
  const _TrackingMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.caramel, size: 48),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    ),
  );
}
