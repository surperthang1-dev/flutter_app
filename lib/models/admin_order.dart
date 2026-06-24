class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String paymentMethod;
  final String status;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final DateTime createdAt;
  final List<AdminOrderItem> items;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  String get shortId => id.length <= 8 ? id : id.substring(id.length - 8);
}

class AdminOrderItem {
  const AdminOrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.size,
    required this.sugar,
    required this.ice,
    required this.note,
    required this.lineTotal,
  });

  final String productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final String size;
  final String sugar;
  final String ice;
  final String note;
  final int lineTotal;
}
