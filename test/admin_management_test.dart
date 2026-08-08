import 'package:flutter_app/models/cart_item.dart';
import 'package:flutter_app/models/discount_code.dart';
import 'package:flutter_app/models/product.dart';
import 'package:flutter_app/models/product_category.dart';
import 'package:flutter_app/services/account_repository.dart';
import 'package:flutter_app/services/admin_repository.dart';
import 'package:flutter_app/services/category_repository.dart';
import 'package:flutter_app/services/delivery_area_repository.dart';
import 'package:flutter_app/services/discount_repository.dart';
import 'package:flutter_app/services/order_repository.dart';
import 'package:flutter_app/services/postgres_auth_repository.dart';
import 'package:flutter_app/services/postgres_product_repository.dart';
import 'package:flutter_app/utils/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('Category management', () {
    final categories = const CategoryRepository();
    final admin = const AdminRepository();
    final menu = const PostgresProductRepository();

    test(
      'rejects empty or duplicate names and hides inactive categories',
      () async {
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        final category = ProductCategory(
          id: 'CAT-$suffix',
          name: 'Danh mục $suffix',
          description: 'Danh mục kiểm thử',
          isActive: true,
          productCount: 0,
        );
        final productId = 'product-$suffix';
        addTearDown(() async {
          await admin.deleteProduct(productId);
          await _deleteCategory(category.id);
        });

        await expectLater(
          categories.saveCategory(
            ProductCategory(
              id: 'empty-$suffix',
              name: '   ',
              description: '',
              isActive: true,
              productCount: 0,
            ),
          ),
          throwsA(anything),
        );

        await categories.saveCategory(category);
        await expectLater(
          categories.saveCategory(
            ProductCategory(
              id: 'duplicate-$suffix',
              name: '  danh mục $suffix  ',
              description: '',
              isActive: true,
              productCount: 0,
            ),
          ),
          throwsA(isA<CategoryException>()),
        );

        await admin.saveProduct(
          Product(
            id: productId,
            name: 'Món danh mục $suffix',
            description: 'Sản phẩm kiểm thử danh mục',
            price: 32000,
            category: category.name,
            categoryId: category.id,
            imageLabel: 'Kiểm thử',
            accentColor: AppColors.caramel,
          ),
        );
        expect(
          (await menu.fetchProducts()).any(
            (product) => product.id == productId,
          ),
          isTrue,
        );
        await expectLater(
          categories.deleteCategory(category.id),
          throwsA(anything),
        );

        await categories.setActive(id: category.id, isActive: false);
        expect(
          (await menu.fetchProducts()).any(
            (product) => product.id == productId,
          ),
          isFalse,
        );
      },
    );
  });

  group('Discount codes and order snapshots', () {
    final discounts = const DiscountRepository();
    final auth = const PostgresAuthRepository();
    final orders = const OrderRepository();
    final areas = const DeliveryAreaRepository();

    test(
      'validates discounts and stores an immutable discount snapshot',
      () async {
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        final now = DateTime.now();
        final fixed = _discount(
          id: 'fixed-$suffix',
          code: 'FIX$suffix',
          type: DiscountType.fixed,
          value: 10000,
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1)),
        );
        final percentage = _discount(
          id: 'percent-$suffix',
          code: 'PCT$suffix',
          type: DiscountType.percentage,
          value: 25,
          maximumDiscount: 12000,
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1)),
        );
        final disabled = _discount(
          id: 'disabled-$suffix',
          code: 'OFF$suffix',
          type: DiscountType.fixed,
          value: 5000,
          isActive: false,
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1)),
        );
        final expired = _discount(
          id: 'expired-$suffix',
          code: 'OLD$suffix',
          type: DiscountType.fixed,
          value: 5000,
          startAt: now.subtract(const Duration(days: 3)),
          endAt: now.subtract(const Duration(days: 1)),
        );
        final usedUp = _discount(
          id: 'used-$suffix',
          code: 'USED$suffix',
          type: DiscountType.fixed,
          value: 5000,
          usageLimit: 0,
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1)),
        );
        final identity = _identity();
        String? orderId;
        addTearDown(() async {
          await _deleteTestAccount(identity.phone);
          for (final discount in [
            fixed,
            percentage,
            disabled,
            expired,
            usedUp,
          ]) {
            await _deleteDiscount(discount.id);
          }
        });

        for (final discount in [fixed, percentage, disabled, expired, usedUp]) {
          await discounts.saveDiscountCode(discount);
        }

        expect(
          (await discounts.validateCode(
            code: fixed.code,
            subtotal: 60000,
          )).amount,
          10000,
        );
        expect(
          (await discounts.validateCode(
            code: percentage.code,
            subtotal: 80000,
          )).amount,
          12000,
        );
        await expectLater(
          discounts.validateCode(code: 'NONE$suffix', subtotal: 60000),
          throwsA(isA<DiscountException>()),
        );
        await expectLater(
          discounts.validateCode(code: disabled.code, subtotal: 60000),
          throwsA(isA<DiscountException>()),
        );
        await expectLater(
          discounts.validateCode(code: expired.code, subtotal: 60000),
          throwsA(isA<DiscountException>()),
        );
        await expectLater(
          discounts.validateCode(code: usedUp.code, subtotal: 60000),
          throwsA(isA<DiscountException>()),
        );

        final area = (await areas.fetchAreas()).first;
        final user = await auth.register(
          fullName: 'Discount Test ${identity.suffix}',
          phone: identity.phone,
          email: identity.email,
          password: 'secret123',
          addressDetail: '12 Đường Test',
          addressNote: 'Gọi trước khi giao',
          deliveryAreaId: area.id,
        );
        orderId = await orders.createOrder(
          user: user,
          paymentMethod: 'Tiền mặt khi nhận hàng',
          discountCodeId: fixed.id,
          items: [_cartItem()],
        );
        final saved = await orders.fetchOrderForUser(
          userId: user.id,
          orderId: orderId,
        );
        expect(saved, isNotNull);
        expect(saved!.discountCode, fixed.code);
        expect(saved.discountAmount, 10000);
        expect(
          saved.total,
          saved.subtotal - saved.discountAmount + saved.deliveryFee,
        );
        expect(saved.items, hasLength(1));

        await discounts.setActive(id: fixed.id, isActive: false);
        final unchanged = await orders.fetchOrderForUser(
          userId: user.id,
          orderId: orderId,
        );
        expect(unchanged!.discountAmount, 10000);
      },
    );
  });

  group('Account administration and user order isolation', () {
    final auth = const PostgresAuthRepository();
    final accounts = const AccountRepository();
    final orders = const OrderRepository();
    final areas = const DeliveryAreaRepository();

    test(
      'locks accounts safely and never exposes another users orders',
      () async {
        final one = _identity();
        final two = _identity();
        addTearDown(() async {
          await _deleteTestAccount(one.phone);
          await _deleteTestAccount(two.phone);
        });
        final area = (await areas.fetchAreas()).first;
        final userOne = await auth.register(
          fullName: 'Isolation One ${one.suffix}',
          phone: one.phone,
          email: one.email,
          password: 'secret123',
          addressDetail: '1 Đường Test',
          addressNote: 'Gọi trước khi giao',
          deliveryAreaId: area.id,
        );
        final userTwo = await auth.register(
          fullName: 'Isolation Two ${two.suffix}',
          phone: two.phone,
          email: two.email,
          password: 'secret123',
          addressDetail: '2 Đường Test',
          addressNote: 'Gọi trước khi giao',
          deliveryAreaId: area.id,
        );
        final orderId = await orders.createOrder(
          user: userOne,
          paymentMethod: 'Tiền mặt khi nhận hàng',
          items: [_cartItem()],
        );
        final oneOrders = await orders.fetchOrdersForUser(userOne.id);
        final twoOrders = await orders.fetchOrdersForUser(userTwo.id);
        expect(oneOrders.any((order) => order.id == orderId), isTrue);
        expect(twoOrders.any((order) => order.id == orderId), isFalse);

        final admin = await auth.login(
          phone: '0999999999',
          password: 'admin123',
        );
        await expectLater(
          accounts.setAccountActive(
            actorId: admin.id,
            accountId: admin.id,
            isActive: false,
          ),
          throwsA(isA<AccountException>()),
        );
        await accounts.setAccountActive(
          actorId: admin.id,
          accountId: userOne.id,
          isActive: false,
        );
        await expectLater(
          auth.login(phone: userOne.phone, password: 'secret123'),
          throwsA(isA<AuthException>()),
        );
        await accounts.setAccountActive(
          actorId: admin.id,
          accountId: userOne.id,
          isActive: true,
        );
        expect(
          (await auth.login(
            phone: userOne.phone,
            password: 'secret123',
          )).isActive,
          isTrue,
        );
      },
    );
  });
}

DiscountCode _discount({
  required String id,
  required String code,
  required DiscountType type,
  required int value,
  required DateTime startAt,
  required DateTime endAt,
  bool isActive = true,
  int? maximumDiscount,
  int? usageLimit,
}) {
  return DiscountCode(
    id: id,
    code: code,
    description: 'Mã kiểm thử',
    type: type,
    discountValue: value,
    minimumOrderValue: 0,
    maximumDiscount: maximumDiscount,
    usageLimit: usageLimit,
    usedCount: 0,
    startAt: startAt,
    endAt: endAt,
    isActive: isActive,
  );
}

int _identitySerial = 0;

_TestIdentity _identity() {
  final suffix = (DateTime.now().microsecondsSinceEpoch + _identitySerial++)
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
  final connection = await _connection();
  try {
    await connection.runTx((session) async {
      await session.execute(
        Sql.named('''
          DELETE FROM orders
          WHERE user_id = (SELECT id FROM app_users WHERE phone = @phone)
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

Future<void> _deleteCategory(String id) async {
  final connection = await _connection();
  try {
    await connection.execute(
      Sql.named('DELETE FROM categories WHERE id = @id'),
      parameters: {'id': id},
    );
  } finally {
    await connection.close();
  }
}

Future<void> _deleteDiscount(String id) async {
  final connection = await _connection();
  try {
    await connection.execute(
      Sql.named('DELETE FROM discount_codes WHERE id = @id'),
      parameters: {'id': id},
    );
  } finally {
    await connection.close();
  }
}

Future<Connection> _connection() => Connection.open(
  Endpoint(
    host: '127.0.0.1',
    port: 5432,
    database: 'coffee_viet_24h',
    username: 'postgres',
    password: 'postgres',
  ),
  settings: const ConnectionSettings(sslMode: SslMode.disable),
);

CartItem _cartItem() {
  return CartItem(
    id: 'test-item',
    product: const Product(
      id: 'test-product',
      name: 'Cà phê kiểm thử',
      description: 'Sản phẩm kiểm thử',
      price: 35000,
      category: 'Cà phê',
      categoryId: 'test-category',
      imageLabel: 'Test',
      accentColor: AppColors.caramel,
    ),
    size: 'M',
    sugar: '70%',
    ice: 'Vừa',
    note: '',
    quantity: 2,
  );
}
