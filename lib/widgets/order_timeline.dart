import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/order_status.dart';
import '../utils/app_colors.dart';

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.orderStatus == OrderStatus.cancelled) {
      return _CancelledTimeline(order: order);
    }

    final steps = [
      _TimelineStep(
        title: 'Đã đặt hàng',
        subtitle: 'Đơn hàng đã được gửi đến cửa hàng.',
        time: order.createdAt,
      ),
      _TimelineStep(
        title: 'Đã xác nhận',
        subtitle: 'Cửa hàng đã nhận và xác nhận đơn của bạn.',
        time: order.confirmedAt,
      ),
      _TimelineStep(
        title: 'Đang chuẩn bị',
        subtitle: 'Barista đang chuẩn bị đồ uống của bạn.',
        time: order.preparingAt,
      ),
      _TimelineStep(
        title: 'Đang giao hàng',
        subtitle: 'Đơn hàng đang được giao đến địa chỉ của bạn.',
        time: order.deliveringAt,
      ),
      _TimelineStep(
        title: 'Hoàn thành',
        subtitle: 'Đơn đã giao thành công. Cảm ơn bạn!',
        time: order.completedAt,
      ),
    ];
    final completedCount = switch (order.orderStatus) {
      OrderStatus.pending => 1,
      OrderStatus.confirmed => 2,
      OrderStatus.preparing => 3,
      OrderStatus.delivering => 4,
      OrderStatus.completed => 5,
      OrderStatus.cancelled => 0,
    };

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final done = index < completedCount;
        final active = done && index == completedCount - 1;
        return _TimelineRow(
          step: step,
          isDone: done,
          isActive: active,
          isLast: index == steps.length - 1,
        );
      }),
    );
  }
}

class _CancelledTimeline extends StatelessWidget {
  const _CancelledTimeline({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_rounded, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn hàng đã bị hủy',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.cancelReason?.trim().isNotEmpty == true
                      ? 'Lý do: ${order.cancelReason}'
                      : 'Cửa hàng chưa cung cấp lý do hủy.',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    height: 1.35,
                  ),
                ),
                if (order.cancelledAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDateTime(order.cancelledAt!),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  final _TimelineStep step;
  final bool isDone;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? (isActive ? AppColors.orange : AppColors.success)
        : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  height: 26,
                  width: 26,
                  decoration: BoxDecoration(
                    color: isDone ? color : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : Icons.circle_outlined,
                    color: isDone ? Colors.white : AppColors.textMuted,
                    size: 15,
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            color: isDone
                                ? AppColors.textDark
                                : AppColors.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (step.time != null)
                        Text(
                          _formatDateTime(step.time!),
                          style: TextStyle(
                            color: isActive
                                ? AppColors.orange
                                : AppColors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDone || isActive
                        ? step.subtitle
                        : 'Chờ cửa hàng cập nhật trạng thái.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.3,
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
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String title;
  final String subtitle;
  final DateTime? time;
}

String _formatDateTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} · ${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
