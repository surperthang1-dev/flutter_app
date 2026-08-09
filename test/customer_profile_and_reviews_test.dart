import 'package:flutter_app/services/delivery_area_repository.dart';
import 'package:flutter_app/services/postgres_auth_repository.dart';
import 'package:flutter_app/services/product_review_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('Customer profile and product reviews', () {
    final auth = const PostgresAuthRepository();
    final areas = const DeliveryAreaRepository();
    final reviews = const ProductReviewRepository();

    test(
      'changes contact information and password, then creates one updatable review',
      () async {
        final suffix = DateTime.now().microsecondsSinceEpoch
            .remainder(100000000)
            .toString()
            .padLeft(8, '0');
        final originalPhone = '09$suffix';
        final updatedPhone = '08$suffix';
        final area = (await areas.fetchAreas()).first;
        addTearDown(() async {
          await _deleteAccount(originalPhone);
          await _deleteAccount(updatedPhone);
        });

        final registered = await auth.register(
          fullName: 'Profile Test $suffix',
          phone: originalPhone,
          email: 'profile-$suffix@coffeeviet.local',
          password: 'secret123',
          addressDetail: '10 Đường Kiểm Thử',
          addressNote: 'Gọi trước cổng chính',
          deliveryAreaId: area.id,
        );
        final updated = await auth.updateProfile(
          user: registered,
          fullName: 'Khách hàng đã cập nhật',
          phone: updatedPhone,
          email: 'updated-$suffix@coffeeviet.local',
          addressDetail: '22 Đường Mới',
          addressNote: 'Tầng 2, gọi trước',
          deliveryAreaId: area.id,
          currentPassword: 'secret123',
        );
        expect(updated.fullName, 'Khách hàng đã cập nhật');
        expect(updated.phone, updatedPhone);
        expect(updated.displayAddress, '22 Đường Mới (Tầng 2, gọi trước)');

        await expectLater(
          auth.login(phone: originalPhone, password: 'secret123'),
          throwsA(isA<AuthException>()),
        );
        await auth.changePassword(
          user: updated,
          currentPassword: 'secret123',
          newPassword: 'newsecret123',
        );
        await expectLater(
          auth.login(phone: updatedPhone, password: 'secret123'),
          throwsA(isA<AuthException>()),
        );
        final loggedIn = await auth.login(
          phone: updatedPhone,
          password: 'newsecret123',
        );

        await reviews.submitReview(
          user: loggedIn,
          productId: 'bac-xiu',
          rating: 5,
          comment: 'Cà phê thơm, đóng gói cẩn thận.',
        );
        var overview = await reviews.fetchOverview(
          productId: 'bac-xiu',
          viewerUserId: loggedIn.id,
        );
        expect(overview.reviewCount, greaterThanOrEqualTo(1));
        final firstReview = overview.reviews.firstWhere(
          (review) => review.userId == loggedIn.id,
        );
        expect(firstReview.rating, 5);
        expect(firstReview.isMine, isTrue);

        await reviews.submitReview(
          user: loggedIn,
          productId: 'bac-xiu',
          rating: 4,
          comment: 'Cà phê thơm, giao hàng nhanh.',
        );
        overview = await reviews.fetchOverview(
          productId: 'bac-xiu',
          viewerUserId: loggedIn.id,
        );
        final ownReviews = overview.reviews
            .where((review) => review.userId == loggedIn.id)
            .toList();
        expect(ownReviews, hasLength(1));
        expect(ownReviews.single.rating, 4);
        expect(ownReviews.single.comment, 'Cà phê thơm, giao hàng nhanh.');

        await expectLater(
          reviews.submitReview(
            user: loggedIn,
            productId: 'bac-xiu',
            rating: 0,
            comment: 'Không hợp lệ',
          ),
          throwsA(isA<ProductReviewException>()),
        );
      },
    );
  });
}

Future<void> _deleteAccount(String phone) async {
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
    await connection.execute(
      Sql.named('DELETE FROM app_users WHERE phone = @phone'),
      parameters: {'phone': phone},
    );
  } finally {
    await connection.close();
  }
}
