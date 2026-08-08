import 'package:flutter_app/models/cart_item.dart';
import 'package:flutter_app/models/order_draft.dart';
import 'package:flutter_app/models/order_status.dart';
import 'package:flutter_app/models/product.dart';
import 'package:flutter_app/services/delivery_area_repository.dart';
import 'package:flutter_app/services/order_repository.dart';
import 'package:flutter_app/services/order_workflow_service.dart';
import 'package:flutter_app/services/postgres_auth_repository.dart';
import 'package:flutter_app/services/registration_validator.dart';
import 'package:flutter_app/utils/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('Coffee order domain', () {
    test('registration requires a delivery area', () {
      expect(
        RegistrationValidator.deliveryAreaId(null),
        'Vui lòng chọn khu vực giao hàng.',
      );
      expect(RegistrationValidator.deliveryAreaId('quan-1'), isNull);
      expect(
        RegistrationValidator.addressNote(''),
        'Vui lòng nhập ghi chú để giao hàng chính xác.',
      );
      expect(RegistrationValidator.addressNote('Gọi trước khi giao'), isNull);
    });

    test('calculates subtotal, fee, total, and immutable item snapshots', () {
      final draft = OrderDraft.fromCart(
        items: [_cartItem(quantity: 2)],
        shippingFee: 18000,
      );

      expect(draft.items, hasLength(1));
      expect(draft.items.single.productName, 'Cà phê sữa đá');
      expect(draft.items.single.unitPrice, 40000);
      expect(draft.subtotal, 80000);
      expect(draft.shippingFee, 18000);
      expect(draft.total, 98000);
      expect(draft.initialStatus, OrderStatus.pending);
    });

    test('only admins can move orders and transitions cannot skip steps', () {
      const workflow = OrderWorkflowService();
      expect(
        () => workflow.validateTransition(
          actorIsAdmin: false,
          from: OrderStatus.pending,
          to: OrderStatus.confirmed,
        ),
        throwsA(isA<OrderWorkflowException>()),
      );
      expect(
        () => workflow.validateTransition(
          actorIsAdmin: true,
          from: OrderStatus.pending,
          to: OrderStatus.delivering,
        ),
        throwsA(isA<OrderWorkflowException>()),
      );
      expect(
        () => workflow.validateTransition(
          actorIsAdmin: true,
          from: OrderStatus.pending,
          to: OrderStatus.cancelled,
        ),
        throwsA(isA<OrderWorkflowException>()),
      );
      expect(
        () => workflow.validateTransition(
          actorIsAdmin: true,
          from: OrderStatus.confirmed,
          to: OrderStatus.cancelled,
          cancelReason: 'Sản phẩm đã hết',
        ),
        returnsNormally,
      );
      expect(
        workflow.canTransition(
          from: OrderStatus.completed,
          to: OrderStatus.pending,
        ),
        isFalse,
      );
      expect(
        workflow.canTransition(
          from: OrderStatus.cancelled,
          to: OrderStatus.confirmed,
        ),
        isFalse,
      );
    });
  });

  group('PostgreSQL local flow', () {
    final authRepository = const PostgresAuthRepository();
    final areaRepository = const DeliveryAreaRepository();
    final orderRepository = const OrderRepository();

    test(
      'rejects duplicate account, snapshots fee, persists order, and records admin cancellation',
      () async {
        final identity = _identity();
        final areas = await areaRepository.fetchAreas(includeInactive: true);
        final area = areas.firstWhere((value) => value.id == 'quan-1');
        final originalFee = area.shippingFee;
        final originalActive = area.isActive;
        addTearDown(() async {
          await areaRepository.updateArea(
            id: area.id,
            shippingFee: originalFee,
            isActive: originalActive,
          );
          await _deleteTestAccount(identity.phone);
        });

        final user = await authRepository.register(
          fullName: 'Test Coffee ${identity.suffix}',
          phone: identity.phone,
          email: identity.email,
          password: 'secret123',
          addressDetail: '12 Đường Test, Quận 1',
          addressNote: 'Gọi trước khi giao',
          deliveryAreaId: area.id,
        );
        await expectLater(
          authRepository.register(
            fullName: 'Trùng tài khoản',
            phone: identity.phone,
            email: identity.email,
            password: 'secret123',
            addressDetail: '12 Đường Test, Quận 1',
            addressNote: 'Gọi trước khi giao',
            deliveryAreaId: area.id,
          ),
          throwsA(isA<AuthException>()),
        );

        final orderId = await orderRepository.createOrder(
          user: user,
          paymentMethod: 'Tiền mặt khi nhận hàng',
          items: [_cartItem()],
          note: 'Không lấy hóa đơn giấy',
        );
        final persisted = await const OrderRepository().fetchOrderForUser(
          userId: user.id,
          orderId: orderId,
        );
        expect(persisted, isNotNull);
        expect(persisted!.orderStatus, OrderStatus.pending);
        expect(persisted.items, hasLength(1));
        expect(persisted.deliveryFee, originalFee);
        expect(persisted.total, persisted.subtotal + persisted.deliveryFee);

        await areaRepository.updateArea(
          id: area.id,
          shippingFee: originalFee + 5000,
          isActive: originalActive,
        );
        final afterFeeChange = await orderRepository.fetchOrderForUser(
          userId: user.id,
          orderId: orderId,
        );
        expect(afterFeeChange!.deliveryFee, originalFee);

        final admin = await authRepository.login(
          phone: '0999999999',
          password: 'admin123',
        );
        await orderRepository.transitionOrder(
          actor: admin,
          orderId: orderId,
          nextStatus: OrderStatus.confirmed,
        );
        await orderRepository.transitionOrder(
          actor: admin,
          orderId: orderId,
          nextStatus: OrderStatus.cancelled,
          cancelReason: 'Sản phẩm đã hết',
        );
        final cancelled = await orderRepository.fetchOrderForUser(
          userId: user.id,
          orderId: orderId,
        );
        expect(cancelled!.orderStatus, OrderStatus.cancelled);
        expect(cancelled.cancelReason, 'Sản phẩm đã hết');
      },
    );

    test('an inactive area cannot receive a new order', () async {
      final identity = _identity();
      final areas = await areaRepository.fetchAreas(includeInactive: true);
      final area = areas.firstWhere((value) => value.id == 'quan-3');
      final originalFee = area.shippingFee;
      final originalActive = area.isActive;
      addTearDown(() async {
        await areaRepository.updateArea(
          id: area.id,
          shippingFee: originalFee,
          isActive: originalActive,
        );
        await _deleteTestAccount(identity.phone);
      });

      final user = await authRepository.register(
        fullName: 'Test Inactive ${identity.suffix}',
        phone: identity.phone,
        email: identity.email,
        password: 'secret123',
        addressDetail: '18 Đường Test, Quận 3',
        addressNote: 'Gọi trước khi giao',
        deliveryAreaId: area.id,
      );
      await areaRepository.updateArea(
        id: area.id,
        shippingFee: originalFee,
        isActive: false,
      );
      await expectLater(
        orderRepository.createOrder(
          user: user,
          paymentMethod: 'Tiền mặt khi nhận hàng',
          items: [_cartItem()],
        ),
        throwsA(isA<OrderException>()),
      );
    });
  });
}

CartItem _cartItem({int quantity = 1}) {
  return CartItem(
    id: 'test-item',
    product: const Product(
      id: 'test-ca-phe',
      name: 'Cà phê sữa đá',
      description: 'Sản phẩm kiểm thử',
      price: 35000,
      category: 'Cà phê',
      imageLabel: 'Cà phê',
      accentColor: AppColors.caramel,
    ),
    size: 'M',
    sugar: '70%',
    ice: 'Vừa',
    note: '',
    quantity: quantity,
  );
}

_TestIdentity _identity() {
  final suffix = DateTime.now().microsecondsSinceEpoch
      .remainder(100000000)
      .toString()
      .padLeft(8, '0');
  return _TestIdentity(
    suffix: suffix,
    phone: '09$suffix',
    email: 'test-$suffix@coffeeviet.local',
  );
}

class _TestIdentity {
  const _TestIdentity({
    required this.suffix,
    required this.phone,
    required this.email,
  });

  final String suffix;
  final String phone;
  final String email;
}

Future<void> _deleteTestAccount(String phone) async {
  final connection = await Connection.open(
    Endpoint(
      host: '127.0.0.1',
      port: 5432,
      database: 'coffee_viet_24h',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
  try {
    await connection.runTx((session) async {
      await session.execute(
        Sql.named('''
          DELETE FROM orders
          WHERE user_id = (
            SELECT id
            FROM app_users
            WHERE phone = @phone
          )
        '''),
        parameters: {'phone': phone},
      );
      await session.execute(
        Sql.named('DELETE FROM app_users WHERE phone = @phone'),
        parameters: {'phone': phone},
      );
    });
  } finally {
    await connection.close();
  }
}
