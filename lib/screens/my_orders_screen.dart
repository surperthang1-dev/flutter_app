import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/order_status.dart';
import '../providers/auth_provider.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import 'order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with WidgetsBindingObserver {
  final _repository = const OrderRepository();
  Future<List<AdminOrder>>? _future;
  String? _userId;
  _OrderGroup _group = _OrderGroup.processing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.of(context).user;
    if (user == null || user.id == _userId) return;
    _userId = user.id;
    _future = _repository.fetchOrdersForUser(user.id);
  }

  @override
  void didUpdateWidget(covariant MyOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final user = AuthScope.of(context).user;
    if (user == null) return;
    late final Future<List<AdminOrder>> future;
    setState(() {
      future = _repository.fetchOrdersForUser(user.id);
      _future = future;
    });
    await future;
  }

  List<AdminOrder> _filter(List<AdminOrder> orders) {
    return orders.where((order) {
      return switch (_group) {
        _OrderGroup.processing => order.orderStatus.isProcessing,
        _OrderGroup.completed => order.orderStatus == OrderStatus.completed,
        _OrderGroup.cancelled => order.orderStatus == OrderStatus.cancelled,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Đơn hàng của tôi')),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<AdminOrder>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _OrdersError(
                    onRetry: _refresh,
                    error: snapshot.error!,
                  );
                }
                final orders = _filter(snapshot.data!);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
                    children: [
                      const Text(
                        'Theo dõi đơn hàng theo cập nhật thực tế từ cửa hàng.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<_OrderGroup>(
                        segments: const [
                          ButtonSegment(
                            value: _OrderGroup.processing,
                            label: Text('Đang xử lý'),
                          ),
                          ButtonSegment(
                            value: _OrderGroup.completed,
                            label: Text('Hoàn thành'),
                          ),
                          ButtonSegment(
                            value: _OrderGroup.cancelled,
                            label: Text('Đã hủy'),
                          ),
                        ],
                        selected: {_group},
                        onSelectionChanged: (value) {
                          setState(() => _group = value.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (orders.isEmpty)
                        const _OrdersEmpty()
                      else
                        ...orders.map(
                          (order) => _MyOrderCard(
                            order: order,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OrderTrackingScreen(
                                    showAppBar: true,
                                    orderId: order.id,
                                  ),
                                ),
                              );
                              _refresh();
                            },
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

enum _OrderGroup { processing, completed, cancelled }

class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({required this.order, required this.onTap});

  final AdminOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = order.orderStatus == OrderStatus.cancelled
        ? Colors.red.shade700
        : order.orderStatus == OrderStatus.completed
        ? AppColors.success
        : AppColors.caramel;
    final preview = order.items
        .take(2)
        .map((item) => item.productName)
        .join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.shortId}',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    order.orderStatus.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preview.isEmpty ? '${order.itemCount} sản phẩm' : preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              '${order.itemCount} món · Tiền sản phẩm ${formatVnd(order.subtotal)}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Phí giao ${formatVnd(order.deliveryFee)}${order.discountAmount > 0 ? ' · Giảm ${formatVnd(order.discountAmount)}' : ''}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatVnd(order.total),
                  style: const TextStyle(
                    color: AppColors.coffee,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.receipt_long_outlined, size: 17),
                label: const Text('Xem chi tiết'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 42, color: AppColors.caramel),
        SizedBox(height: 10),
        Text(
          'Chưa có đơn hàng ở nhóm này',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 4),
        Text(
          'Các đơn hàng được tạo sẽ xuất hiện tại đây.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.caramel,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không thể tải đơn hàng',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 14),
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
