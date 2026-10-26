import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/cart_items.dart';
import 'package:myapp/widgets/product_detail_sheet.dart';

void main() {
  setUp(() => CartItems.items.value = []);
  tearDown(() => CartItems.items.value = []);

  Widget sheet({required int stock}) => MaterialApp(
    home: Scaffold(
      body: ProductDetailSheet(
        name: 'Brown Backpack',
        description: 'Everyday bag',
        price: '₱2,000.00',
        image: '',
        productId: 'product-1',
        availableQuantity: stock,
        sizes: const ['One size'],
        colors: const ['Brown'],
      ),
    ),
  );

  testWidgets('plus stops at available stock', (tester) async {
    await tester.pumpWidget(sheet(stock: 3));
    final plus = find.byTooltip('Increase quantity');
    await tester.scrollUntilVisible(plus, 180);
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: plus, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Up to 3 more'), findsOneWidget);
  });

  testWidgets('quantity already in bag reduces the remaining limit', (
    tester,
  ) async {
    CartItems.items.value = [
      CartLine(
        name: 'Brown Backpack',
        description: 'Everyday bag',
        price: '₱2,000.00',
        image: '',
        productId: 'product-1',
        size: 'One size',
        color: 'Brown',
        quantity: 2,
      ),
    ];
    await tester.pumpWidget(sheet(stock: 3));
    final plus = find.byTooltip('Increase quantity');
    await tester.scrollUntilVisible(plus, 180);

    expect(find.text('Up to 1 more'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: plus, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('out-of-stock product cannot be added', (tester) async {
    await tester.pumpWidget(sheet(stock: 0));
    await tester.scrollUntilVisible(find.text('No more available to add'), 180);

    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('No more available to add'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Increase quantity'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('rapid product taps open only one sheet and allow reopening', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  for (var i = 0; i < 3; i++) {
                    unawaited(
                      ProductDetailSheet.show(
                        context,
                        name: 'Brown Backpack',
                        description: 'Everyday bag',
                        price: '2000.00',
                        image: '',
                        productId: 'product-1',
                        availableQuantity: 3,
                      ),
                    );
                  }
                },
                child: const Text('Open product'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open product'));
    await tester.pumpAndSettle();
    expect(
      find.byType(ProductDetailSheet, skipOffstage: false),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailSheet, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Open product'));
    await tester.pumpAndSettle();
    expect(
      find.byType(ProductDetailSheet, skipOffstage: false),
      findsOneWidget,
    );
  });
}
