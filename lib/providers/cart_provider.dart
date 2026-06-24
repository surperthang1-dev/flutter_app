import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  int get deliveryFee => _items.isEmpty ? 0 : 15000;

  int get total => subtotal + deliveryFee;

  void addProduct({
    required Product product,
    required String size,
    required String sugar,
    required String ice,
    required String note,
    required int quantity,
  }) {
    final newItem = CartItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      product: product,
      size: size,
      sugar: sugar,
      ice: ice,
      note: note.trim(),
      quantity: quantity,
    );

    final existingIndex = _items.indexWhere(
      (item) => item.hasSameOptions(newItem),
    );
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _items.add(newItem);
    }

    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }

    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

class CartScope extends InheritedNotifier<CartProvider> {
  const CartScope({
    super.key,
    required CartProvider super.notifier,
    required super.child,
  });

  static CartProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope không tồn tại trong widget tree.');
    return scope!.notifier!;
  }
}
