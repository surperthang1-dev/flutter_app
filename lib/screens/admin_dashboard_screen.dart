import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/admin_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_visual.dart';
import 'admin_delivery_areas_screen.dart';
import 'admin_order_detail_screen.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  void _logout() {
    AuthScope.of(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      AdminHomePage(),
      AdminProductsPage(),
      AdminOrdersPage(),
      AdminStatsPage(),
      AdminInvoicePage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản trị Coffee Việt 24H'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Khu vực & phí giao hàng',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminDeliveryAreasScreen(),
                ),
              );
            },
            icon: const Icon(Icons.local_shipping_rounded),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.caramel.withValues(alpha: 0.22),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.coffee_outlined),
            selectedIcon: Icon(Icons.coffee_rounded),
            label: 'Sản phẩm',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt_rounded),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_download_outlined),
            selectedIcon: Icon(Icons.file_download_rounded),
            label: 'Hoá đơn',
          ),
        ],
      ),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _repository = const AdminRepository();
  late Future<AdminSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchSummary();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchSummary());
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          FutureBuilder<AdminSummary>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingBlock();
              }
              if (snapshot.hasError) return _ErrorBlock(error: snapshot.error);
              return _DashboardOverview(
                name: user?.fullName ?? 'Admin',
                summary: snapshot.data!,
                onRefresh: _refresh,
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _repository = const AdminRepository();
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchProducts();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchProducts());
  }

  Future<void> _openEditor([Product? product]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductEditor(
        product: product,
        onSave: _repository.saveProduct,
        onPickImage: _repository.pickAndStoreProductImage,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá sản phẩm'),
        content: Text('Xoá vĩnh viễn "${product.name}" khỏi menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xoá ${product.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xoá sản phẩm: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _PageTitle(
              title: 'Sản phẩm',
              action: IconButton.filled(
                tooltip: 'Thêm sản phẩm',
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingBlock()
            else if (snapshot.hasError)
              _ErrorBlock(error: snapshot.error)
            else if (snapshot.data!.isEmpty)
              const _EmptyBlock(
                icon: Icons.coffee_rounded,
                title: 'Chưa có sản phẩm',
                body: 'Bấm nút thêm để tạo món đầu tiên cho menu.',
              )
            else
              ...snapshot.data!.map(
                (product) => _ProductAdminTile(
                  product: product,
                  onEdit: () => _openEditor(product),
                  onDelete: () => _deleteProduct(product),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _repository = const AdminRepository();
  late Future<List<AdminOrder>> _future;
  String? _exportingId;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOrders();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchOrders());
  }

  Future<void> _export(AdminOrder order) async {
    if (_exportingId != null) return;
    setState(() => _exportingId = order.id);
    try {
      final path = await _repository.exportInvoice(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất hoá đơn: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminOrder>>(
      future: _future,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _PageTitle(
              title: 'Đơn hàng',
              action: IconButton.filled(
                tooltip: 'Làm mới',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState != ConnectionState.done)
              const _LoadingBlock()
            else if (snapshot.hasError)
              _ErrorBlock(error: snapshot.error)
            else if (snapshot.data!.isEmpty)
              const _EmptyBlock(
                icon: Icons.receipt_long_rounded,
                title: 'Chưa có đơn hàng',
                body: 'Khi khách thanh toán, đơn sẽ xuất hiện ở đây.',
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _selectedStatus == null,
                    onSelected: (_) => setState(() => _selectedStatus = null),
                  ),
                  ...[
                    'pending',
                    'confirmed',
                    'preparing',
                    'delivering',
                    'completed',
                    'cancelled',
                  ].map(
                    (status) => ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: _selectedStatus == status,
                      onSelected: (_) =>
                          setState(() => _selectedStatus = status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...snapshot.data!
                  .where(
                    (order) =>
                        _selectedStatus == null ||
                        order.status == _selectedStatus,
                  )
                  .map(
                    (order) => _OrderTile(
                      order: order,
                      isExporting: _exportingId == order.id,
                      onExport: () => _export(order),
                      onManage: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminOrderDetailScreen(order: order),
                          ),
                        );
                        if (updated == true) _refresh();
                      },
                    ),
                  ),
            ],
          ],
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'preparing':
        return 'Đang chuẩn bị';
      case 'delivering':
        return 'Đang giao';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }
}

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  final _repository = const AdminRepository();
  late Future<AdminSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchSummary();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchSummary());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
      children: [
        _PageTitle(
          title: 'Thống kê',
          action: IconButton.filled(
            tooltip: 'Làm mới',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<AdminSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _LoadingBlock();
            }
            if (snapshot.hasError) return _ErrorBlock(error: snapshot.error);
            final summary = snapshot.data!;
            return Column(
              children: [
                _StatRow('Doanh thu hôm nay', formatVnd(summary.todayRevenue)),
                _StatRow('Tổng doanh thu', formatVnd(summary.revenue)),
                _StatRow('Tổng đơn hàng', summary.orderCount.toString()),
                _StatRow('Sản phẩm đang bán', summary.productCount.toString()),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdminInvoicePage extends StatefulWidget {
  const AdminInvoicePage({super.key});

  @override
  State<AdminInvoicePage> createState() => _AdminInvoicePageState();
}

class _AdminInvoicePageState extends State<AdminInvoicePage> {
  final _repository = const AdminRepository();
  bool _isExportingOrder = false;
  bool _isExportingMenu = false;

  Future<void> _exportLatestOrder() async {
    if (_isExportingOrder) return;
    setState(() => _isExportingOrder = true);
    try {
      final path = await _repository.exportInvoice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất hoá đơn đơn hàng: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingOrder = false);
    }
  }

  Future<void> _exportMenu() async {
    if (_isExportingMenu) return;
    setState(() => _isExportingMenu = true);
    try {
      final path = await _repository.exportMenuInvoice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất bảng giá menu: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingMenu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
      children: [
        const _PageTitle(title: 'Hoá đơn'),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _isExportingOrder
              ? 'Đang xuất...'
              : 'Xuất hoá đơn đơn mới nhất',
          icon: Icons.download_rounded,
          onPressed: _isExportingOrder ? null : _exportLatestOrder,
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: _isExportingMenu ? 'Đang xuất...' : 'Xuất bảng giá menu',
          icon: Icons.file_download_rounded,
          onPressed: _isExportingMenu ? null : _exportMenu,
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.name,
    required this.summary,
    required this.onRefresh,
  });

  final String name;
  final AdminSummary summary;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DashboardMetric(
        'Tổng doanh thu',
        formatVnd(summary.revenue),
        Icons.account_balance_wallet_rounded,
        AppColors.caramel,
      ),
      _DashboardMetric(
        'Đơn hàng',
        summary.orderCount.toString(),
        Icons.receipt_long_rounded,
        AppColors.orange,
      ),
      _DashboardMetric(
        'Sản phẩm',
        summary.productCount.toString(),
        Icons.coffee_rounded,
        AppColors.success,
      ),
      _DashboardMetric(
        'Khách hàng',
        summary.userCount.toString(),
        Icons.people_alt_rounded,
        AppColors.espresso,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.coffeeDark, AppColors.espresso],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2A211915),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: onRefresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.cream,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'DOANH THU HÔM NAY',
                style: TextStyle(
                  color: AppColors.caramel,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatVnd(summary.todayRevenue),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroMetric(
                    label: 'Sản phẩm',
                    value: summary.productCount.toString(),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  _HeroMetric(
                    label: 'Đơn hàng',
                    value: summary.orderCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tổng quan',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) =>
              _DashboardMetricCard(item: items[index]),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({required this.item});

  final _DashboardMetric item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ProductAdminTile extends StatelessWidget {
  const _ProductAdminTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ProductVisual(product: product, height: 58, iconSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.category} - ${formatVnd(product.price)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sửa',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Xoá sản phẩm',
            onPressed: onDelete,
            color: Colors.red.shade700,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.isExporting,
    required this.onExport,
    required this.onManage,
  });

  final AdminOrder order;
  final bool isExporting;
  final VoidCallback onExport;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.shortId} - ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.caramel.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: const TextStyle(
                    color: AppColors.caramel,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.customerPhone} - ${order.deliveryAddress}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip('${order.itemCount} món'),
              _MiniChip(order.paymentMethod),
              _MiniChip(formatVnd(order.total)),
              if (order.deliveryAreaName?.isNotEmpty == true)
                _MiniChip(order.deliveryAreaName!),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item.productName} x${item.quantity} (${item.size}, đường ${item.sugar}, đá ${item.ice})',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Xử lý đơn'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isExporting ? null : onExport,
              icon: Icon(
                isExporting
                    ? Icons.hourglass_empty_rounded
                    : Icons.download_rounded,
              ),
              label: Text(isExporting ? 'Đang xuất' : 'Xuất hoá đơn'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xử lý';
      case 'preparing':
        return 'Đang pha chế';
      case 'delivering':
        return 'Đang giao';
      case 'completed':
        return 'Hoàn tất';
      default:
        return status;
    }
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    required this.product,
    required this.onSave,
    required this.onPickImage,
  });

  final Product? product;
  final Future<void> Function(Product product) onSave;
  final Future<String?> Function(String idHint) onPickImage;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _labelController;
  late final TextEditingController _imageController;
  Color _accentColor = AppColors.caramel;
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _idController = TextEditingController(text: product?.id ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: product?.category ?? 'Cà phê',
    );
    _labelController = TextEditingController(text: product?.imageLabel ?? '');
    _imageController = TextEditingController(text: product?.imageAsset ?? '');
    _accentColor = product?.accentColor ?? AppColors.caramel;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _labelController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    final id = _idController.text.trim().isEmpty
        ? _slug(_nameController.text)
        : _idController.text.trim();
    final product = Product(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: int.parse(_priceController.text.trim()),
      category: _categoryController.text.trim(),
      imageLabel: _labelController.text.trim(),
      accentColor: _accentColor,
      imageAsset: _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
    );

    try {
      await widget.onSave(product);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu sản phẩm: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final path = await widget.onPickImage(
        _idController.text.trim().isEmpty
            ? _nameController.text.trim()
            : _idController.text.trim(),
      );
      if (path == null || !mounted) return;
      setState(() => _imageController.text = path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _nameController,
                    _descriptionController,
                    _priceController,
                    _categoryController,
                    _labelController,
                    _imageController,
                  ]),
                  builder: (context, _) {
                    final preview = Product(
                      id: _idController.text.trim().isEmpty
                          ? 'preview'
                          : _idController.text.trim(),
                      name: _nameController.text.trim().isEmpty
                          ? 'Tên sản phẩm'
                          : _nameController.text.trim(),
                      description: _descriptionController.text.trim().isEmpty
                          ? 'Mô tả sản phẩm'
                          : _descriptionController.text.trim(),
                      price: int.tryParse(_priceController.text.trim()) ?? 0,
                      category: _categoryController.text.trim().isEmpty
                          ? 'Danh mục'
                          : _categoryController.text.trim(),
                      imageLabel: _labelController.text.trim().isEmpty
                          ? 'Ảnh'
                          : _labelController.text.trim(),
                      accentColor: _accentColor,
                      imageAsset: _imageController.text.trim().isEmpty
                          ? null
                          : _imageController.text.trim(),
                    );
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ProductVisual(
                        product: preview,
                        height: 140,
                        iconSize: 34,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idController,
                  enabled: widget.product == null,
                  decoration: const InputDecoration(
                    labelText: 'Mã sản phẩm',
                    hintText: 'Tự tạo nếu bỏ trống',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Giá'),
                        validator: _price,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(labelText: 'Nhãn ảnh'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(
                    labelText: 'Ảnh sản phẩm (image_asset)',
                    hintText: 'Chọn ảnh hoặc nhập đường dẫn ảnh',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isPickingImage ? null : _pickImage,
                    icon: Icon(
                      _isPickingImage
                          ? Icons.hourglass_empty_rounded
                          : Icons.image_rounded,
                    ),
                    label: Text(
                      _isPickingImage ? 'Đang chọn ảnh...' : 'Chọn ảnh từ máy',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Màu nhấn',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    for (final color in const [
                      AppColors.caramel,
                      AppColors.orange,
                      AppColors.success,
                      Color(0xFF8B5D3B),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: () => setState(() => _accentColor = color),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accentColor == color
                                    ? AppColors.coffee
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _isSaving ? 'Đang lưu...' : 'Lưu sản phẩm',
                  icon: Icons.save_rounded,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Không được bỏ trống.';
    return null;
  }

  String? _price(String? value) {
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed <= 0) return 'Giá chưa hợp lệ.';
    return null;
  }

  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.isEmpty) return 'sp-${DateTime.now().millisecondsSinceEpoch}';
    return slug;
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.caramel, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        error.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
