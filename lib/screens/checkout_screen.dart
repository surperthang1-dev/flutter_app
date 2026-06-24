import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/order_repository.dart';
import '../utils/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/primary_button.dart';
import 'order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderRepository = const OrderRepository();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  String _payment = 'Tiền mặt khi nhận hàng';
  bool _seededUser = false;
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
    if (_seededUser) return;
    final user = AuthScope.of(context).user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.phone ?? '';
    _addressController.text = user?.address ?? '';
    _seededUser = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = CartScope.of(context);
    final auth = AuthScope.of(context);
    if (!_formKey.currentState!.validate() ||
        cart.items.isEmpty ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final orderId = await _orderRepository.createOrder(
        user: auth.user,
        customerName: _nameController.text,
        customerPhone: _phoneController.text,
        deliveryAddress: _addressController.text,
        paymentMethod: _payment,
        subtotal: cart.subtotal,
        deliveryFee: cart.deliveryFee,
        total: cart.total,
        items: cart.items,
        note: _noteController.text,
      );

      cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OrderTrackingScreen(showAppBar: true, orderId: orderId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đặt hàng: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coffee,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thanh toán'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
          children: [
            const _SectionTitle('Thông tin nhận hàng'),
            const SizedBox(height: 12),
            _SurfaceBlock(
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ tên người nhận',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '090xxxxxxx',
                    ),
                    validator: _phone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ giao hàng',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'Số nhà, tên đường, phường, quận...',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho quán',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Phương thức thanh toán'),
            const SizedBox(height: 12),
            ..._paymentOptions.map((option) {
              final isSelected = option.name == _payment;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _payment = option.name),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.coffee : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.caramel
                            : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          color: isSelected
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
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                option.description,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
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
            const SizedBox(height: 18),
            _SurfaceBlock(
              child: Column(
                children: [
                  _TotalRow('Tạm tính', formatVnd(cart.subtotal)),
                  const SizedBox(height: 10),
                  _TotalRow('Phí giao hàng', formatVnd(cart.deliveryFee)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: AppColors.border),
                  ),
                  _TotalRow(
                    'Tổng thanh toán',
                    formatVnd(cart.total),
                    highlight: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
          ),
        ),
        child: SafeArea(
          child: PrimaryButton(
            label: _isSubmitting ? 'Đang tạo đơn...' : 'Xác nhận đặt hàng',
            icon: Icons.check_circle_rounded,
            onPressed: cart.items.isEmpty || _isSubmitting ? null : _placeOrder,
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Vui lòng nhập thông tin.';
    return null;
  }

  String? _phone(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 9) return 'Số điện thoại chưa hợp lệ.';
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _SurfaceBlock extends StatelessWidget {
  const _SurfaceBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1.1),
      ),
      child: child,
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? AppColors.textDark : AppColors.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: highlight ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.caramel : AppColors.textDark,
            fontWeight: FontWeight.w900,
            fontSize: highlight ? 22 : 15,
          ),
        ),
      ],
    );
  }
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
