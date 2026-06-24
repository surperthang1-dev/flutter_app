import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/providers/cart_provider.dart';

void main() {
  testWidgets('Coffee app renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      CartScope(notifier: CartProvider(), child: const CoffeeVietApp()),
    );

    expect(find.text('Cà Phê Việt 24H'), findsOneWidget);
    expect(find.text('Đậm vị Việt, giao tận nơi'), findsOneWidget);
  });
}
