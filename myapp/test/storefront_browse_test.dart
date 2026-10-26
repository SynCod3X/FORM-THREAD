import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';
import 'package:myapp/screens/shop_screen.dart';

void main() {
  testWidgets('home search opens the shop with the entered query', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Storefront()));

    await tester.enterText(find.byType(TextField).first, 'linen');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'linen',
    );
  });

  testWidgets('home filter opens the selected shop category', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Storefront()));

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Shoes'));
    await tester.tap(find.text('SHOW PRODUCTS'));
    await tester.pumpAndSettle();

    expect(find.byType(ShopScreen), findsOneWidget);
    expect(
      tester.widget<ShopScreen>(find.byType(ShopScreen)).initialCategory,
      'Shoes',
    );
  });
}
