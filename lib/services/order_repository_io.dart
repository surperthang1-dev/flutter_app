import 'package:postgres/postgres.dart';

import '../config/database_config.dart';
import '../models/admin_order.dart';
import '../models/auth_user.dart';
import '../models/cart_item.dart';
import '../models/checkout_snapshot.dart';
import '../models/delivery_area.dart';
import '../models/order_draft.dart';
import '../models/order_status.dart';
import 'order_workflow_service.dart';

class OrderRepository {
  const OrderRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<CheckoutSnapshot> fetchCheckoutSnapshot(AuthUser user) async {
    final connection = await _open();
    try {
      return await _fetchCheckoutSnapshot(connection, user.id);
    } finally {
      await connection.close();
    }
  }

  Future<String> createOrder({
    required AuthUser user,
    required String paymentMethod,
    required List<CartItem> items,
    String? discountCodeId,
    String? note,
  }) async {
    final connection = await _open();
    try {
      return await connection.runTx((session) async {
        final checkout = await _fetchCheckoutSnapshot(session, user.id);
        if (!checkout.deliveryArea.isActive) {
          throw const OrderException(
            'Khu vực giao hàng của bạn đang tạm ngừng. Vui lòng chọn khu vực khác.',
          );
        }

        final draft = OrderDraft.fromCart(
          items: items,
          shippingFee: checkout.deliveryArea.shippingFee,
        );
        final orderId = 'CFV-${DateTime.now().microsecondsSinceEpoch}';

        await session.execute(
          Sql.named('''
            INSERT INTO orders (
              id,
              user_id,
              delivery_area_id,
              delivery_area_name,
              customer_name,
              customer_phone,
              delivery_address,
              payment_method,
              subtotal,
              delivery_fee,
              total,
              status,
              discount_code_id,
              note
            )
            VALUES (
              @id,
              CAST(@userId AS UUID),
              @deliveryAreaId,
              @deliveryAreaName,
              @customerName,
              @customerPhone,
              @deliveryAddress,
              @paymentMethod,
              @subtotal,
              @deliveryFee,
              @total,
              @status,
              NULLIF(@discountCodeId, ''),
              NULLIF(@note, '')
            )
          '''),
          parameters: {
            'id': orderId,
            'userId': user.id,
            'deliveryAreaId': checkout.deliveryArea.id,
            'deliveryAreaName': checkout.deliveryArea.name,
            'customerName': checkout.fullName,
            'customerPhone': checkout.phone,
            'deliveryAddress': checkout.deliveryAddress,
            'paymentMethod': paymentMethod.trim(),
            'subtotal': draft.subtotal,
            'deliveryFee': draft.shippingFee,
            'total': draft.total,
            'status': draft.initialStatus.databaseValue,
            'discountCodeId': discountCodeId?.trim() ?? '',
            'note': note?.trim() ?? '',
          },
        );

        for (final item in draft.items) {
          await session.execute(
            Sql.named('''
              INSERT INTO order_items (
                order_id,
                product_id,
                product_name,
                unit_price,
                quantity,
                size,
                sugar,
                ice,
                note,
                line_total
              )
              VALUES (
                @orderId,
                @productId,
                @productName,
                @unitPrice,
                @quantity,
                @size,
                @sugar,
                @ice,
                NULLIF(@note, ''),
                @lineTotal
              )
            '''),
            parameters: {
              'orderId': orderId,
              'productId': item.productId,
              'productName': item.productName,
              'unitPrice': item.unitPrice,
              'quantity': item.quantity,
              'size': item.size,
              'sugar': item.sugar,
              'ice': item.ice,
              'note': item.note,
              'lineTotal': item.lineTotal,
            },
          );
        }

        await session.execute(
          Sql.named('''
            INSERT INTO order_status_history (order_id, from_status, to_status)
            VALUES (@orderId, NULL, @status)
          '''),
          parameters: {
            'orderId': orderId,
            'status': OrderStatus.pending.databaseValue,
          },
        );

        return orderId;
      });
    } finally {
      await connection.close();
    }
  }

  Future<List<AdminOrder>> fetchOrdersForUser(String userId) async {
    final connection = await _open();
    try {
      return await _fetchOrders(
        connection,
        whereClause: 'orders.user_id = CAST(@userId AS UUID)',
        parameters: {'userId': userId},
      );
    } finally {
      await connection.close();
    }
  }

  Future<AdminOrder?> fetchOrderForUser({
    required String userId,
    required String orderId,
  }) async {
    final connection = await _open();
    try {
      final orders = await _fetchOrders(
        connection,
        whereClause:
            'orders.user_id = CAST(@userId AS UUID) AND orders.id = @orderId',
        parameters: {'userId': userId, 'orderId': orderId},
      );
      return orders.isEmpty ? null : orders.first;
    } finally {
      await connection.close();
    }
  }

  Future<List<AdminOrder>> fetchAllOrders() async {
    final connection = await _open();
    try {
      return await _fetchOrders(connection);
    } finally {
      await connection.close();
    }
  }

  Future<void> transitionOrder({
    required AuthUser actor,
    required String orderId,
    required OrderStatus nextStatus,
    String? cancelReason,
  }) async {
    final connection = await _open();
    try {
      await connection.runTx((session) async {
        final rows = await session.execute(
          Sql.named('''
            SELECT status
            FROM orders
            WHERE id = @orderId
            FOR UPDATE
          '''),
          parameters: {'orderId': orderId},
        );
        if (rows.isEmpty) {
          throw const OrderException('Không tìm thấy đơn hàng.');
        }

        final current = OrderStatusX.fromDatabase(
          rows.first.toColumnMap()['status'] as String,
        );
        const OrderWorkflowService().validateTransition(
          actorIsAdmin: actor.isAdmin,
          from: current,
          to: nextStatus,
          cancelReason: cancelReason,
        );

        await session.execute(
          Sql.named('''
            UPDATE orders
            SET status = @nextStatus,
                cancel_reason = CASE
                  WHEN @nextStatus = 'cancelled' THEN NULLIF(@cancelReason, '')
                  ELSE cancel_reason
                END,
                confirmed_at = CASE
                  WHEN @nextStatus = 'confirmed' THEN NOW()
                  ELSE confirmed_at
                END,
                preparing_at = CASE
                  WHEN @nextStatus = 'preparing' THEN NOW()
                  ELSE preparing_at
                END,
                delivering_at = CASE
                  WHEN @nextStatus = 'delivering' THEN NOW()
                  ELSE delivering_at
                END,
                completed_at = CASE
                  WHEN @nextStatus = 'completed' THEN NOW()
                  ELSE completed_at
                END,
                cancelled_at = CASE
                  WHEN @nextStatus = 'cancelled' THEN NOW()
                  ELSE cancelled_at
                END,
                updated_at = NOW()
            WHERE id = @orderId
          '''),
          parameters: {
            'orderId': orderId,
            'nextStatus': nextStatus.databaseValue,
            'cancelReason': cancelReason?.trim() ?? '',
          },
        );

        await session.execute(
          Sql.named('''
            INSERT INTO order_status_history (
              order_id,
              from_status,
              to_status,
              note,
              changed_by_user_id
            )
            VALUES (
              @orderId,
              @fromStatus,
              @toStatus,
              NULLIF(@note, ''),
              CAST(@actorId AS UUID)
            )
          '''),
          parameters: {
            'orderId': orderId,
            'fromStatus': current.databaseValue,
            'toStatus': nextStatus.databaseValue,
            'note': cancelReason?.trim() ?? '',
            'actorId': actor.id,
          },
        );
      });
    } finally {
      await connection.close();
    }
  }

  Future<CheckoutSnapshot> _fetchCheckoutSnapshot(
    Session session,
    String userId,
  ) async {
    final rows = await session.execute(
      Sql.named('''
        SELECT
          users.full_name,
          users.phone,
          COALESCE(users.address_detail, users.address, '') AS address_detail,
          users.address_note,
          areas.id AS delivery_area_id,
          areas.name AS delivery_area_name,
          areas.shipping_fee,
          areas.is_active
        FROM app_users users
        LEFT JOIN delivery_areas areas ON areas.id = users.delivery_area_id
        WHERE users.id = CAST(@userId AS UUID)
      '''),
      parameters: {'userId': userId},
    );
    if (rows.isEmpty) {
      throw const OrderException('Không tìm thấy tài khoản đặt hàng.');
    }
    final data = rows.first.toColumnMap();
    final areaId = data['delivery_area_id'] as String?;
    final address = data['address_detail'] as String;
    final addressNote = data['address_note'] as String?;
    if (areaId == null ||
        address.trim().isEmpty ||
        (addressNote?.trim().isEmpty ?? true)) {
      throw const OrderException(
        'Tài khoản chưa có địa chỉ, ghi chú và khu vực giao hàng hợp lệ.',
      );
    }

    return CheckoutSnapshot(
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      addressDetail: address,
      addressNote: addressNote,
      deliveryArea: DeliveryArea(
        id: areaId,
        name: data['delivery_area_name'] as String,
        shippingFee: (data['shipping_fee'] as num).toInt(),
        isActive: data['is_active'] as bool,
      ),
    );
  }

  Future<List<AdminOrder>> _fetchOrders(
    Session session, {
    String whereClause = 'TRUE',
    Map<String, dynamic> parameters = const {},
  }) async {
    final orderRows = await session.execute(
      Sql.named('''
        SELECT
          orders.id,
          orders.customer_name,
          orders.customer_phone,
          orders.delivery_address,
          orders.delivery_area_id,
          COALESCE(orders.delivery_area_name, areas.name, '')
            AS delivery_area_name,
          orders.payment_method,
          orders.status,
          orders.subtotal,
          orders.delivery_fee,
          orders.discount_code,
          orders.discount_type,
          orders.discount_value,
          orders.discount_amount,
          orders.total,
          orders.note,
          orders.cancel_reason,
          orders.created_at,
          orders.confirmed_at,
          orders.preparing_at,
          orders.delivering_at,
          orders.completed_at,
          orders.cancelled_at
        FROM orders
        LEFT JOIN delivery_areas areas ON areas.id = orders.delivery_area_id
        WHERE $whereClause
        ORDER BY
          CASE orders.status WHEN 'pending' THEN 0 ELSE 1 END,
          orders.created_at DESC
        LIMIT 100
      '''),
      parameters: parameters,
    );

    if (orderRows.isEmpty) return const [];

    final itemRows = await session.execute('''
      SELECT
        order_id,
        product_id,
        product_name,
        unit_price,
        quantity,
        size,
        sugar,
        ice,
        COALESCE(note, '') AS note,
        line_total
      FROM order_items
      ORDER BY id ASC
    ''');

    final itemsByOrder = <String, List<AdminOrderItem>>{};
    for (final row in itemRows) {
      final data = row.toColumnMap();
      final orderId = data['order_id'] as String;
      itemsByOrder
          .putIfAbsent(orderId, () => [])
          .add(
            AdminOrderItem(
              productId: data['product_id'] as String,
              productName: data['product_name'] as String,
              unitPrice: (data['unit_price'] as num).toInt(),
              quantity: (data['quantity'] as num).toInt(),
              size: data['size'] as String,
              sugar: data['sugar'] as String,
              ice: data['ice'] as String,
              note: data['note'] as String,
              lineTotal: (data['line_total'] as num).toInt(),
            ),
          );
    }

    return orderRows.map((row) {
      final data = row.toColumnMap();
      final id = data['id'] as String;
      return AdminOrder(
        id: id,
        customerName: data['customer_name'] as String,
        customerPhone: data['customer_phone'] as String,
        deliveryAddress: data['delivery_address'] as String,
        deliveryAreaId: data['delivery_area_id'] as String?,
        deliveryAreaName: data['delivery_area_name'] as String?,
        paymentMethod: data['payment_method'] as String,
        status: data['status'] as String,
        subtotal: (data['subtotal'] as num).toInt(),
        deliveryFee: (data['delivery_fee'] as num).toInt(),
        discountCode: data['discount_code'] as String?,
        discountType: data['discount_type'] as String?,
        discountValue: (data['discount_value'] as num?)?.toInt(),
        discountAmount: (data['discount_amount'] as num?)?.toInt() ?? 0,
        total: (data['total'] as num).toInt(),
        createdAt: data['created_at'] as DateTime,
        cancelReason: data['cancel_reason'] as String?,
        confirmedAt: data['confirmed_at'] as DateTime?,
        preparingAt: data['preparing_at'] as DateTime?,
        deliveringAt: data['delivering_at'] as DateTime?,
        completedAt: data['completed_at'] as DateTime?,
        cancelledAt: data['cancelled_at'] as DateTime?,
        items: itemsByOrder[id] ?? const [],
      );
    }).toList();
  }

  Future<Connection> _open() {
    return Connection.open(
      Endpoint(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username,
        password: config.password,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
  }
}

class OrderException implements Exception {
  const OrderException(this.message);

  final String message;

  @override
  String toString() => message;
}
