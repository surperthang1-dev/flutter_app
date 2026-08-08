import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/order_status.dart';
import '../providers/auth_provider.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({super.key, required this.order});

  final AdminOrder order;

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final _repository = const OrderRepository();
  bool _isSaving = false;

  Future<void> _transition(
    OrderStatus nextStatus, {
    String? cancelReason,
  }) async {
    final actor = AuthScope.of(context).user;
    if (actor == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _repository.transitionOrder(
        actor: actor,
        orderId: widget.order.id,
        nextStatus: nextStatus,
        cancelReason: cancelReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật đơn: ${nextStatus.label}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coffeeDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAdvance(OrderStatus nextStatus) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nextStatus == OrderStatus.confirmed
              ? 'Xác nhận đơn hàng'
              : 'Cập nhật trạng thái',
        ),
        content: Text('Chuyển đơn sang trạng thái "${nextStatus.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (approved == true) await _transition(nextStatus);
  }

  Future<void> _cancelOrder() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelOrderDialog(),
    );
    if (reason != null) {
      await _transition(OrderStatus.cancelled, cancelReason: reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xử lý đơn hàng')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 124),
        children: [
          _OrderOverview(order: order),
          const SizedBox(height: 16),
          _OrderLines(order: order),
          const SizedBox(height: 16),
          _CustomerCard(order: order),
          const SizedBox(height: 22),
          _ActionPanel(
            order: order,
            isSaving: _isSaving,
            onAdvance: _confirmAdvance,
            onCancel: _cancelOrder,
          ),
        ],
      ),
    );
  }
}

class _OrderOverview extends StatelessWidget {
  const _OrderOverview({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final statusColor = _colorForStatus(order.orderStatus);
    return Container(
      padding: const EdgeInsets.all(18),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.orderStatus.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Đặt lúc ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')} · ${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.border),
          ),
          _MoneyLine('Tạm tính', order.subtotal),
          const SizedBox(height: 7),
          _MoneyLine('Phí giao hàng (snapshot)', order.deliveryFee),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(color: AppColors.border),
          ),
          _MoneyLine('Tổng thanh toán', order.total, highlight: true),
          if (order.cancelReason?.trim().isNotEmpty == true) ...[
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

class _OrderLines extends StatelessWidget {
  const _OrderLines({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sản phẩm',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${item.size} · đường ${item.sugar} · đá ${item.ice}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (item.note.trim().isNotEmpty)
                        Text(
                          'Ghi chú: ${item.note}',
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
        if (order.items.isEmpty)
          const Text(
            'Đơn hàng không có sản phẩm.',
            style: TextStyle(color: AppColors.textMuted),
          ),
      ],
    ),
  );
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khách hàng & giao hàng',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _DetailLine(
          Icons.person_outline_rounded,
          '${order.customerName} · ${order.customerPhone}',
        ),
        const SizedBox(height: 8),
        _DetailLine(Icons.location_on_outlined, order.deliveryAddress),
        if (order.deliveryAreaName?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _DetailLine(Icons.local_shipping_outlined, order.deliveryAreaName!),
        ],
        const SizedBox(height: 8),
        _DetailLine(Icons.payments_outlined, order.paymentMethod),
      ],
    ),
  );
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.order,
    required this.isSaving,
    required this.onAdvance,
    required this.onCancel,
  });

  final AdminOrder order;
  final bool isSaving;
  final ValueChanged<OrderStatus> onAdvance;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final next = switch (order.orderStatus) {
      OrderStatus.pending => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.delivering,
      OrderStatus.delivering => OrderStatus.completed,
      OrderStatus.completed || OrderStatus.cancelled => null,
    };
    final canCancel =
        order.orderStatus == OrderStatus.pending ||
        order.orderStatus == OrderStatus.confirmed ||
        order.orderStatus == OrderStatus.preparing;
    if (next == null && !canCancel) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mutedSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Đơn ở trạng thái kết thúc nên không thể thay đổi thêm.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          PrimaryButton(
            label: isSaving ? 'Đang cập nhật...' : _advanceLabel(next),
            icon: _advanceIcon(next),
            onPressed: isSaving ? null : () => onAdvance(next),
          ),
        if (next != null && canCancel) const SizedBox(height: 10),
        if (canCancel)
          OutlinedButton.icon(
            onPressed: isSaving ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Hủy đơn hàng'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
          ),
      ],
    );
  }

  String _advanceLabel(OrderStatus status) => switch (status) {
    OrderStatus.confirmed => 'Chấp nhận đơn hàng',
    OrderStatus.preparing => 'Bắt đầu chuẩn bị',
    OrderStatus.delivering => 'Chuyển sang đang giao',
    OrderStatus.completed => 'Xác nhận giao thành công',
    _ => status.label,
  };

  IconData _advanceIcon(OrderStatus status) => switch (status) {
    OrderStatus.confirmed => Icons.check_circle_rounded,
    OrderStatus.preparing => Icons.coffee_rounded,
    OrderStatus.delivering => Icons.delivery_dining_rounded,
    OrderStatus.completed => Icons.task_alt_rounded,
    _ => Icons.arrow_forward_rounded,
  };
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  static const _reasons = [
    'Sản phẩm đã hết',
    'Ngoài khu vực giao hàng',
    'Không thể liên hệ khách hàng',
    'Cửa hàng tạm ngừng nhận đơn',
    'Lý do khác',
  ];

  final _otherController = TextEditingController();
  String _selected = _reasons.first;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _selected == 'Lý do khác'
        ? _otherController.text.trim()
        : _selected;
    if (reason.isEmpty) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _selected == 'Lý do khác';
    return AlertDialog(
      title: const Text('Hủy đơn hàng'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vui lòng chọn hoặc nhập lý do hủy để khách hàng theo dõi.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selected,
              items: _reasons
                  .map(
                    (reason) =>
                        DropdownMenuItem(value: reason, child: Text(reason)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selected = value!),
              decoration: const InputDecoration(labelText: 'Lý do hủy'),
            ),
            if (isOther) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Nhập lý do khác',
                  errorText: _otherController.text.trim().isEmpty
                      ? 'Không được để trống.'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Quay lại'),
        ),
        FilledButton.tonal(
          onPressed: _submit,
          child: const Text('Xác nhận hủy'),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.text);

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

Color _colorForStatus(OrderStatus status) => switch (status) {
  OrderStatus.cancelled => Colors.red.shade700,
  OrderStatus.completed => AppColors.success,
  OrderStatus.pending => AppColors.caramel,
  _ => AppColors.coffee,
};
