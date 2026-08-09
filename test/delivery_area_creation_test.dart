import 'package:flutter_app/services/delivery_area_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('Delivery area administration', () {
    final repository = const DeliveryAreaRepository();

    test(
      'new active areas are visible to user selection and duplicates fail',
      () async {
        final suffix = DateTime.now().microsecondsSinceEpoch
            .remainder(100000000)
            .toString();
        final name = 'Khu vực Test $suffix';
        String? areaId;
        addTearDown(() async {
          if (areaId case final id?) await _deleteArea(id);
        });

        final area = await repository.createArea(
          name: '  $name  ',
          shippingFee: 27000,
        );
        areaId = area.id;
        expect(area.name, name);
        expect(area.isActive, isTrue);
        expect(area.shippingFee, 27000);

        final userAreas = await repository.fetchAreas();
        expect(userAreas.any((value) => value.id == area.id), isTrue);

        await expectLater(
          repository.createArea(name: name.toLowerCase(), shippingFee: 15000),
          throwsA(isA<DeliveryAreaException>()),
        );

        await repository.updateArea(
          id: area.id,
          shippingFee: area.shippingFee,
          isActive: false,
        );
        final areasAfterPause = await repository.fetchAreas();
        expect(areasAfterPause.any((value) => value.id == area.id), isFalse);
      },
    );
  });
}

Future<void> _deleteArea(String id) async {
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
      Sql.named('DELETE FROM delivery_areas WHERE id = @id'),
      parameters: {'id': id},
    );
  } finally {
    await connection.close();
  }
}
