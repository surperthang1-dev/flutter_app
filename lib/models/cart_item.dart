import 'product.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.size,
    required this.sugar,
    required this.ice,
    required this.note,
    required this.quantity,
  });

  final String id;
  final Product product;
  final String size;
  final String sugar;
  final String ice;
  final String note;
  final int quantity;

  int get sizeExtra {
    switch (size) {
      case 'M':
        return 5000;
      case 'L':
        return 10000;
      default:
        return 0;
    }
  }

  int get unitPrice => product.price + sizeExtra;

  int get totalPrice => unitPrice * quantity;

  bool hasSameOptions(CartItem other) {
    return product.id == other.product.id &&
        size == other.size &&
        sugar == other.sugar &&
        ice == other.ice &&
        note.trim() == other.note.trim();
  }

  CartItem copyWith({
    String? id,
    Product? product,
    String? size,
    String? sugar,
    String? ice,
    String? note,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      size: size ?? this.size,
      sugar: sugar ?? this.sugar,
      ice: ice ?? this.ice,
      note: note ?? this.note,
      quantity: quantity ?? this.quantity,
    );
  }
}
