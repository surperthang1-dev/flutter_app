import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../widgets/coffee_logo.dart';
import '../widgets/primary_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Giới thiệu'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.coffeeDark, AppColors.coffee],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.caramel.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coffeeDark.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoffeeLogo(size: 72),
                SizedBox(height: 24),
                Text(
                  'Cà Phê Việt 24H',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Đậm vị Việt, giao tận nơi. Ứng dụng đặt cà phê và đồ uống nhanh cho những ngày bận rộn.',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _InfoCard(
            icon: Icons.local_cafe_rounded,
            title: 'Hương vị chủ đạo',
            description:
                'Tập trung vào cà phê phin, bạc xỉu, trà trái cây, trà sữa và bánh ngọt theo phong cách quán cà phê Việt.',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.delivery_dining_rounded,
            title: 'Đặt món và giao hàng',
            description:
                'Người dùng có thể chọn size, lượng đường, lượng đá, ghi chú riêng và theo dõi trạng thái giao hàng.',
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Trải nghiệm thành viên',
            description:
                'Màn tài khoản có điểm tích lũy, hạng thành viên, lịch sử đơn hàng và các khu vực hỗ trợ khách hàng.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.caramel),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Phiên bản demo 1.0.0 - dữ liệu sản phẩm, thanh toán và theo dõi đơn hàng đang được mô phỏng.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Quay lại tài khoản',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.coffeeDark.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.caramel.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.caramel, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
