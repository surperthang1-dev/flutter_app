import 'package:flutter/material.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/option_chip_selector.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_visual.dart';
import '../widgets/quantity_stepper.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _noteController = TextEditingController();
  String _size = 'M';
  String _sugar = '70%';
  String _ice = 'Vừa';
  int _quantity = 1;

  int get _unitPrice {
    final extra = switch (_size) {
      'M' => 5000,
      'L' => 10000,
      _ => 0,
    };
    return widget.product.price + extra;
  }

  int get _total => _unitPrice * _quantity;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _addToCart() {
    CartScope.of(context).addProduct(
      product: widget.product,
      size: _size,
      sugar: _sugar,
      ice: _ice,
      note: _noteController.text,
      quantity: _quantity,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm $_quantity x ${widget.product.name} vào giỏ.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.coffeeDark,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết món'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 136),
        children: [
          ProductVisual(product: widget.product, height: 260, iconSize: 78),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.product.name,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                formatVnd(_unitPrice),
                style: const TextStyle(
                  color: AppColors.coffee,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OptionChipSelector(
                  label: 'Chọn size',
                  options: const ['S', 'M', 'L'],
                  value: _size,
                  onChanged: (value) => setState(() => _size = value),
                ),
                const SizedBox(height: 18),
                OptionChipSelector(
                  label: 'Lượng đường',
                  options: const ['0%', '30%', '50%', '70%', '100%'],
                  value: _sugar,
                  onChanged: (value) => setState(() => _sugar = value),
                ),
                const SizedBox(height: 18),
                OptionChipSelector(
                  label: 'Lượng đá',
                  options: const ['Ít đá', 'Vừa', 'Nhiều đá'],
                  value: _ice,
                  onChanged: (value) => setState(() => _ice = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho quán',
              hintText: 'Ví dụ: ít sữa, không đá, ghi tên lên ly...',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 14),
          _Panel(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Số lượng',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                QuantityStepper(
                  value: _quantity,
                  onChanged: (value) => setState(() => _quantity = value),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng cộng',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatVnd(_total),
                      style: const TextStyle(
                        color: AppColors.coffee,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 176,
                child: PrimaryButton(
                  label: 'Thêm vào giỏ',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: _addToCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
