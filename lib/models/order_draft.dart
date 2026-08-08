import 'cart_item.dart';
import 'order_status.dart';

class OrderLineSnapshot {
  const OrderLineSnapshot({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.size,
    required this.sugar,
    required this.ice,
    required this.note,
  });

  factory OrderLineSnapshot.fromCartItem(CartItem item) {
    return OrderLineSnapshot(
      productId: item.product.id,
      productName: item.product.name,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      size: item.size,
      sugar: item.sugar,
      ice: item.ice,
      note: item.note.trim(),
    );
  }

  final String productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final String size;
  final String sugar;
  final String ice;
  final String note;

  int get lineTotal => unitPrice * quantity;
}

class OrderDraft {
  const OrderDraft._({
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.total,
  });

  factory OrderDraft.fromCart({
    required List<CartItem> items,
    required int shippingFee,
    int discountAmount = 0,
  }) {
    if (items.isEmpty) {
      throw const OrderDraftException('Giỏ hàng đang trống.');
    }
    if (shippingFee < 0) {
      throw const OrderDraftException('Phí giao hàng không hợp lệ.');
    }

    final snapshots = items.map(OrderLineSnapshot.fromCartItem).toList();
    if (snapshots.any((item) => item.quantity <= 0 || item.unitPrice < 0)) {
      throw const OrderDraftException('Sản phẩm trong giỏ hàng không hợp lệ.');
    }

    final subtotal = snapshots.fold<int>(
      0,
      (sum, item) => sum + item.lineTotal,
    );
    if (discountAmount < 0 || discountAmount > subtotal) {
      throw const OrderDraftException('Giảm giá không hợp lệ.');
    }
    return OrderDraft._(
      items: List.unmodifiable(snapshots),
      subtotal: subtotal,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      total: subtotal - discountAmount + shippingFee,
    );
  }

  final List<OrderLineSnapshot> items;
  final int subtotal;
  final int shippingFee;
  final int discountAmount;
  final int total;

  OrderStatus get initialStatus => OrderStatus.pending;
}

class OrderDraftException implements Exception {
  const OrderDraftException(this.message);

  final String message;

  @override
  String toString() => message;
}
