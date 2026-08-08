import '../models/order_status.dart';

class OrderWorkflowService {
  const OrderWorkflowService();

  static const _validTransitions = <OrderStatus, Set<OrderStatus>>{
    OrderStatus.pending: {OrderStatus.confirmed, OrderStatus.cancelled},
    OrderStatus.confirmed: {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing: {OrderStatus.delivering, OrderStatus.cancelled},
    OrderStatus.delivering: {OrderStatus.completed},
    OrderStatus.completed: {},
    OrderStatus.cancelled: {},
  };

  bool canTransition({required OrderStatus from, required OrderStatus to}) {
    return _validTransitions[from]?.contains(to) ?? false;
  }

  void validateTransition({
    required bool actorIsAdmin,
    required OrderStatus from,
    required OrderStatus to,
    String? cancelReason,
  }) {
    if (!actorIsAdmin) {
      throw const OrderWorkflowException(
        'Chỉ quản trị viên mới có thể cập nhật trạng thái đơn hàng.',
      );
    }
    if (to == OrderStatus.cancelled && (cancelReason?.trim().isEmpty ?? true)) {
      throw const OrderWorkflowException('Vui lòng nhập lý do hủy đơn.');
    }
    if (!canTransition(from: from, to: to)) {
      throw OrderWorkflowException(
        'Không thể chuyển đơn từ "${from.label}" sang "${to.label}".',
      );
    }
  }
}

class OrderWorkflowException implements Exception {
  const OrderWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}
