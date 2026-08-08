import 'package:flutter/material.dart';

import '../models/checkout_snapshot.dart';
import '../models/order_draft.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_visual.dart';
import 'order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _orderRepository = const OrderRepository();
  final _noteController = TextEditingController();

  CheckoutSnapshot? _checkout;
  String? _loadError;
  String? _loadedUserId;
  String _payment = 'Tiền mặt khi nhận hàng';
  bool _isLoading = true;
  bool _isSubmitting = false;

  final _paymentOptions = const [
    _PaymentOption(
      name: 'Tiền mặt khi nhận hàng',
      description: 'Thanh toán cho nhân viên giao hàng.',
      icon: Icons.local_atm_rounded,
    ),
    _PaymentOption(
      name: 'Chuyển khoản ngân hàng',
      description: 'Nhận thông tin chuyển khoản khi xác nhận đơn.',
      icon: Icons.account_balance_rounded,
    ),
    _PaymentOption(
      name: 'Ví MoMo / ZaloPay',
      description: 'Thanh toán nhanh bằng ví điện tử.',
      icon: Icons.wallet_rounded,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AuthScope.of(context).user;
    if (user == null || user.id == _loadedUserId) return;
    _loadedUserId = user.id;
    _loadCheckout();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckout() async {
    final user = AuthScope.of(context).user;
    if (user == null) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final checkout = await _orderRepository.fetchCheckoutSnapshot(user);
      if (!mounted) return;
      setState(() {
        _checkout = checkout;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    final user = AuthScope.of(context).user;
    final cart = CartScope.of(context);
    if (user == null ||
        _checkout == null ||
        !_checkout!.deliveryArea.isActive ||
        cart.items.isEmpty ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final orderId = await _orderRepository.createOrder(
        user: user,
        paymentMethod: _payment,
        items: cart.items,
        note: _noteController.text,
      );
      cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.schedule_rounded,
            color: AppColors.caramel,
            size: 40,
          ),
          title: const Text('Đơn đang chờ xác nhận'),
          content: const Text(
            'Cửa hàng sẽ xem và xác nhận đơn của bạn trong thời gian sớm nhất.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Theo dõi đơn'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              OrderTrackingScreen(showAppBar: true, orderId: orderId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đặt hàng: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coffeeDark,
        ),
      );
      await _loadCheckout();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final draft = _checkout == null || cart.items.isEmpty
        ? null
        : OrderDraft.fromCart(
            items: cart.items,
            shippingFee: _checkout!.deliveryArea.shippingFee,
          );
    final canPlace =
        !_isLoading &&
        _loadError == null &&
        _checkout?.deliveryArea.isActive == true &&
        draft != null &&
        !_isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác nhận đơn hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _CheckoutError(error: _loadError!, onRetry: _loadCheckout)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 144),
              children: [
                const _SectionTitle('Sản phẩm đã chọn'),
                const SizedBox(height: 12),
                ...cart.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 56,
                          width: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ProductVisual(
                              product: item.product,
                              height: 56,
                              iconSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} × ${formatVnd(item.unitPrice)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatVnd(item.totalPrice),
                          style: const TextStyle(
                            color: AppColors.coffee,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Địa chỉ giao hàng'),
                const SizedBox(height: 12),
                _AddressCard(checkout: _checkout!),
                const SizedBox(height: 22),
                const _SectionTitle('Phương thức thanh toán'),
                const SizedBox(height: 12),
                ..._paymentOptions.map((option) {
                  final selected = option.name == _payment;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _payment = option.name),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.coffee
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColors.caramel
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              option.icon,
                              color: selected
                                  ? AppColors.caramel
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textDark,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    option.description,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white70
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.caramel,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú đơn hàng',
                    hintText: 'Ví dụ: Ít đá, gọi trước khi giao',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 22),
                _TotalCard(draft: draft!),
                if (!_checkout!.deliveryArea.isActive) ...[
                  const SizedBox(height: 14),
                  const _InactiveAreaNotice(),
                ],
              ],
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: PrimaryButton(
            label: _isSubmitting ? 'Đang tạo đơn...' : 'Đặt hàng',
            icon: Icons.check_circle_rounded,
            onPressed: canPlace ? _placeOrder : null,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textDark,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.checkout});

  final CheckoutSnapshot checkout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.caramel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${checkout.fullName} · ${checkout.phone}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  checkout.deliveryAddress,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: checkout.deliveryArea.isActive
                        ? AppColors.success.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    checkout.deliveryArea.isActive
                        ? checkout.deliveryArea.name
                        : '${checkout.deliveryArea.name} · Tạm ngừng giao',
                    style: TextStyle(
                      color: checkout.deliveryArea.isActive
                          ? AppColors.success
                          : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.draft});

  final OrderDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _MoneyRow('Tổng tiền sản phẩm', draft.subtotal),
          const SizedBox(height: 10),
          _MoneyRow('Phí giao hàng', draft.shippingFee),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.border),
          ),
          _MoneyRow('Tổng thanh toán', draft.total, highlight: true),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.value, {this.highlight = false});

  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: highlight ? AppColors.textDark : AppColors.textMuted,
          fontSize: highlight ? 16 : 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        formatVnd(value),
        style: TextStyle(
          color: highlight ? AppColors.caramel : AppColors.textDark,
          fontSize: highlight ? 21 : 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _InactiveAreaNotice extends StatelessWidget {
  const _InactiveAreaNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Khu vực này đang tạm ngừng giao. Vui lòng cập nhật địa chỉ sang khu vực khác trước khi đặt đơn mới.',
      style: TextStyle(color: AppColors.textDark, height: 1.35),
    ),
  );
}

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_rounded,
            size: 48,
            color: AppColors.caramel,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa thể xác nhận giao hàng',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

class _PaymentOption {
  const _PaymentOption({
    required this.name,
    required this.description,
    required this.icon,
  });

  final String name;
  final String description;
  final IconData icon;
}
