enum OrderStatus {
  pending,
  confirmed,
  preparing,
  delivering,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get databaseValue => name;

  bool get isProcessing => switch (this) {
    OrderStatus.pending ||
    OrderStatus.confirmed ||
    OrderStatus.preparing ||
    OrderStatus.delivering => true,
    OrderStatus.completed || OrderStatus.cancelled => false,
  };

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Chờ cửa hàng xác nhận';
      case OrderStatus.confirmed:
        return 'Đã xác nhận';
      case OrderStatus.preparing:
        return 'Đang chuẩn bị';
      case OrderStatus.delivering:
        return 'Đang giao hàng';
      case OrderStatus.completed:
        return 'Hoàn thành';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }

  static OrderStatus fromDatabase(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => OrderStatus.pending,
    );
  }
}
