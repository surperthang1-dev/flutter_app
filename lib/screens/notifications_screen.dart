import 'package:flutter/material.dart';

import '../models/user_notification.dart';
import '../providers/auth_provider.dart';
import '../services/notification_repository.dart';
import '../utils/app_colors.dart';
import 'completed_order_review_screen.dart';
import 'order_tracking_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = const NotificationRepository();
  Future<List<UserNotification>>? _future;
  String? _userId;
  bool _isMarkingAll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = AuthScope.of(context).user?.id;
    if (userId == null || userId == _userId) return;
    _userId = userId;
    _future = _repository.fetchNotifications(userId);
  }

  Future<void> _refresh() async {
    final userId = AuthScope.of(context).user?.id;
    if (userId == null) return;
    final future = _repository.fetchNotifications(userId);
    setState(() => _future = future);
    await future;
  }

  Future<void> _markAllRead() async {
    final userId = _userId;
    if (userId == null || _isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      await _repository.markAllRead(userId);
      await _refresh();
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _openNotification(UserNotification notification) async {
    final user = AuthScope.of(context).user;
    if (user == null) return;
    if (!notification.isRead) {
      await _repository.markRead(userId: user.id, id: notification.id);
    }
    if (!mounted) return;

    if (notification.type == UserNotificationType.orderCompleted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CompletedOrderReviewScreen(orderId: notification.orderId),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(
            orderId: notification.orderId,
            showAppBar: true,
          ),
        ),
      );
    }
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton.icon(
            onPressed: _isMarkingAll ? null : _markAllRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(_isMarkingAll ? 'Đang đọc...' : 'Đọc tất cả'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<UserNotification>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _NotificationMessage(
                    icon: Icons.error_outline_rounded,
                    title: 'Không thể tải thông báo',
                    body: snapshot.error.toString(),
                    action: _refresh,
                  );
                }
                final notifications = snapshot.data!;
                if (notifications.isEmpty) {
                  return const _NotificationMessage(
                    icon: Icons.notifications_none_rounded,
                    title: 'Chưa có thông báo',
                    body: 'Thông tin về đơn hàng của bạn sẽ xuất hiện tại đây.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NotificationTile(
                      notification: notifications[index],
                      onTap: () => _openNotification(notifications[index]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final UserNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.type) {
      UserNotificationType.orderCreated => AppColors.coffee,
      UserNotificationType.orderDelivering => AppColors.orange,
      UserNotificationType.orderCompleted => AppColors.success,
    };
    final icon = switch (notification.type) {
      UserNotificationType.orderCreated => Icons.receipt_long_rounded,
      UserNotificationType.orderDelivering => Icons.delivery_dining_rounded,
      UserNotificationType.orderCompleted => Icons.verified_rounded,
    };
    final date =
        '${notification.createdAt.day.toString().padLeft(2, '0')}/${notification.createdAt.month.toString().padLeft(2, '0')} · ${notification.createdAt.hour.toString().padLeft(2, '0')}:${notification.createdAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: notification.isRead
          ? AppColors.surface
          : color.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.border
                  : color.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: notification.isRead
                                  ? FontWeight.w800
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        height: 1.35,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      notification.type == UserNotificationType.orderCompleted
                          ? '$date · Chạm để chọn món và đánh giá'
                          : '$date · Chạm để xem đơn hàng',
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.caramel),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
