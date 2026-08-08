import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../utils/app_colors.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    AuthScope.of(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
        children: [
          _ProfileHeader(
            name: user?.fullName ?? 'Khách hàng',
            phone: user?.phone ?? 'Chưa đăng nhập',
            address: user?.displayAddress,
            deliveryAreaName: user?.deliveryAreaName,
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Tài khoản của tôi'),
          const SizedBox(height: 10),
          _TileGroup(
            children: [
              _ProfileTile(
                icon: Icons.history_rounded,
                title: 'Lịch sử đơn hàng',
                subtitle: 'Theo dõi các đơn đã đặt',
                onTap: () {},
              ),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                title: 'Địa chỉ giao hàng',
                subtitle: user?.displayAddress?.isNotEmpty == true
                    ? user!.displayAddress!
                    : 'Chưa lưu địa chỉ',
                onTap: () {},
              ),
              _ProfileTile(
                icon: Icons.local_offer_outlined,
                title: 'Ưu đãi của bạn',
                subtitle: 'Mã giảm giá và chương trình thành viên',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Thông tin & hỗ trợ'),
          const SizedBox(height: 10),
          _TileGroup(
            children: [
              _ProfileTile(
                icon: Icons.security_rounded,
                title: 'Bảo mật tài khoản',
                subtitle: 'Mật khẩu được lưu bằng SHA-256 trong PostgreSQL',
                onTap: () {},
              ),
              _ProfileTile(
                icon: Icons.info_outline_rounded,
                title: 'Về Coffee Việt 24H',
                subtitle: 'Thông tin cửa hàng và ứng dụng',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          _TileGroup(
            children: [
              _ProfileTile(
                icon: Icons.logout_rounded,
                title: 'Đăng xuất',
                subtitle: 'Thoát khỏi tài khoản hiện tại',
                danger: true,
                onTap: () => _logout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.phone,
    required this.address,
    required this.deliveryAreaName,
  });

  final String name;
  final String phone;
  final String? address;
  final String? deliveryAreaName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.coffeeDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.coffee,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (address?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (deliveryAreaName?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    deliveryAreaName!,
                    style: TextStyle(
                      color: AppColors.caramel.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red.shade700 : AppColors.textDark;
    final iconColor = danger ? Colors.red.shade700 : AppColors.coffee;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: danger
              ? Colors.red.shade50
              : AppColors.caramel.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: danger ? Colors.red.shade300 : AppColors.textMuted,
      ),
    );
  }
}
