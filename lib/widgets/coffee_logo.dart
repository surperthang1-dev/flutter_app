import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class CoffeeLogo extends StatelessWidget {
  const CoffeeLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.coffee,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.coffeeDark.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Icon(
        Icons.local_cafe_rounded,
        color: AppColors.cream,
        size: size * 0.52,
      ),
    );
  }
}
