import 'package:flutter/material.dart';

import '../models/admin_account.dart';
import '../models/admin_order.dart';
import '../models/order_status.dart';
import '../providers/auth_provider.dart';
import '../services/account_repository.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({super.key});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  // Admin có thể tìm/lọc tài khoản và khóa mở tài khoản theo đúng role hiện tại.
  final _repository = const AccountRepository();
  final _searchController = TextEditingController();
  late Future<List<AdminAccount>> _future;
  String _query = '';
  _RoleFilter _roleFilter = _RoleFilter.all;
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchAccounts();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _repository.fetchAccounts();
    });
  }

  Future<void> _changeActivity(AdminAccount account, bool isActive) async {
    // Kiểm tra role ở UI trước, repository và trigger DB tiếp tục bảo vệ ở tầng dữ liệu.
    final actor = AuthScope.of(context).user;
    if (actor == null || !actor.isAdmin) {
      _message('Bạn không có quyền quản lý tài khoản.');
      return;
    }
    if (actor.id == account.id && !isActive) {
      _message('Không thể khóa chính tài khoản đang đăng nhập.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
        content: Text(
          '${isActive ? 'Cho phép' : 'Ngăn'} ${account.fullName} ${isActive ? 'đăng nhập lại' : 'đăng nhập vào ứng dụng'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: isActive
                ? null
                : FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isActive ? 'Mở khóa' : 'Khóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || _updatingId != null) return;
    setState(() => _updatingId = account.id);
    try {
      await _repository.setAccountActive(
        actorId: actor.id,
        accountId: account.id,
        isActive: isActive,
      );
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  void _openDetails(AdminAccount account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminAccountDetailScreen(account: account),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = AuthScope.of(context).user;
    if (actor == null || !actor.isAdmin) return const _AccessDenied();

    return FutureBuilder<List<AdminAccount>>(
      future: _future,
      builder: (context, snapshot) {
        final accounts = (snapshot.data ?? const <AdminAccount>[])
            .where(_matches)
            .toList();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            children: [
              const Text(
                'Tài khoản',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm tên, số điện thoại hoặc email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._RoleFilter.values.map(
                    (filter) => ChoiceChip(
                      label: Text(filter.label),
                      selected: _roleFilter == filter,
                      onSelected: (_) => setState(() => _roleFilter = filter),
                    ),
                  ),
                  ..._ActivityFilter.values.map(
                    (filter) => ChoiceChip(
                      label: Text(filter.label),
                      selected: _activityFilter == filter,
                      onSelected: (_) =>
                          setState(() => _activityFilter = filter),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _AccountState(
                  icon: Icons.error_outline_rounded,
                  title: 'Không thể tải tài khoản',
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Tải lại'),
                  ),
                )
              else if (accounts.isEmpty)
                const _AccountState(
                  icon: Icons.people_outline_rounded,
                  title: 'Không có tài khoản phù hợp',
                )
              else
                ...accounts.map(
                  (account) => _AccountTile(
                    account: account,
                    isUpdating: _updatingId == account.id,
                    onTap: () => _openDetails(account),
                    onChanged: (value) => _changeActivity(account, value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _matches(AdminAccount account) {
    final text = '${account.fullName} ${account.phone} ${account.email ?? ''}'
        .toLowerCase();
    final roleMatches = switch (_roleFilter) {
      _RoleFilter.all => true,
      _RoleFilter.admin => account.isAdmin,
      _RoleFilter.user => !account.isAdmin,
    };
    final activityMatches = switch (_activityFilter) {
      _ActivityFilter.all => true,
      _ActivityFilter.active => account.isActive,
      _ActivityFilter.locked => !account.isActive,
    };
    return roleMatches &&
        activityMatches &&
        (_query.isEmpty || text.contains(_query));
  }
}

class AdminAccountDetailScreen extends StatefulWidget {
  const AdminAccountDetailScreen({super.key, required this.account});

  final AdminAccount account;

  @override
  State<AdminAccountDetailScreen> createState() =>
      _AdminAccountDetailScreenState();
}

class _AdminAccountDetailScreenState extends State<AdminAccountDetailScreen> {
  final _orders = const OrderRepository();
  late Future<List<AdminOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _orders.fetchOrdersForUser(widget.account.id);
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chi tiết tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _DetailLine('ID', account.id),
                _DetailLine('Số điện thoại', account.phone),
                if (account.email?.isNotEmpty == true)
                  _DetailLine('Email', account.email!),
                _DetailLine(
                  'Vai trò',
                  account.isAdmin ? 'Quản trị viên' : 'Khách hàng',
                ),
                _DetailLine('Khu vực', account.deliveryAreaName ?? '—'),
                _DetailLine(
                  'Trạng thái',
                  account.isActive ? 'Đang hoạt động' : 'Đã khóa',
                ),
                _DetailLine('Ngày tạo', _dateTimeLabel(account.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Lịch sử đơn hàng',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<AdminOrder>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text('Không thể tải lịch sử đơn.');
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Chưa có đơn hàng.');
              }
              return Column(
                children: snapshot.data!
                    .map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('#${order.shortId}'),
                        subtitle: Text(order.orderStatus.label),
                        trailing: Text(
                          formatVnd(order.total),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isUpdating,
    required this.onTap,
    required this.onChanged,
  });

  final AdminAccount account;
  final bool isUpdating;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: account.isAdmin
                ? AppColors.caramel.withValues(alpha: 0.18)
                : AppColors.mutedSurface,
            child: Icon(
              account.isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: account.isAdmin ? AppColors.caramel : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.fullName,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${account.isAdmin ? 'Admin' : 'User'} · ${account.orderCount} đơn',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  account.phone,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: account.isActive,
            onChanged: isUpdating ? null : onChanged,
          ),
        ],
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.textDark)),
        ),
      ],
    ),
  );
}

class _AccountState extends StatelessWidget {
  const _AccountState({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: AppColors.caramel),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Bạn không có quyền truy cập khu vực quản trị.'),
  );
}

enum _RoleFilter { all, admin, user }

extension on _RoleFilter {
  String get label => switch (this) {
    _RoleFilter.all => 'Tất cả role',
    _RoleFilter.admin => 'Admin',
    _RoleFilter.user => 'User',
  };
}

enum _ActivityFilter { all, active, locked }

extension on _ActivityFilter {
  String get label => switch (this) {
    _ActivityFilter.all => 'Mọi trạng thái',
    _ActivityFilter.active => 'Đang hoạt động',
    _ActivityFilter.locked => 'Đã khóa',
  };
}

String _dateTimeLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
