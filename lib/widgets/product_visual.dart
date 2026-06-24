import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/app_colors.dart';
import 'product_image.dart';

class ProductVisual extends StatelessWidget {
  const ProductVisual({
    super.key,
    required this.product,
    this.height = 128,
    this.iconSize = 44,
  });

  final Product product;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final imageAsset = product.imageAsset;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _backgroundFor(product.category),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: imageAsset == null || imageAsset.isEmpty
            ? _ProductIconFallback(product: product, iconSize: iconSize)
            : Padding(
                padding: const EdgeInsets.all(10),
                child: ProductImage(
                  path: imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return _ProductIconFallback(
                      product: product,
                      iconSize: iconSize,
                      showMissingIcon: true,
                    );
                  },
                ),
              ),
      ),
    );
  }

  Color _backgroundFor(String category) {
    if (category == 'Trà' || category == 'Đá xay') {
      return AppColors.leaf.withValues(alpha: 0.09);
    }
    if (category == 'Bánh ngọt') {
      return AppColors.orange.withValues(alpha: 0.11);
    }
    return AppColors.caramel.withValues(alpha: 0.12);
  }
}

class _ProductIconFallback extends StatelessWidget {
  const _ProductIconFallback({
    required this.product,
    required this.iconSize,
    this.showMissingIcon = false,
  });

  final Product product;
  final double iconSize;
  final bool showMissingIcon;

  @override
  Widget build(BuildContext context) {
    final icon = showMissingIcon
        ? Icons.image_not_supported_outlined
        : product.category == 'Bánh ngọt'
        ? Icons.cake_rounded
        : product.category == 'Trà'
        ? Icons.eco_rounded
        : Icons.local_cafe_rounded;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: product.accentColor, size: iconSize),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            product.imageLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
