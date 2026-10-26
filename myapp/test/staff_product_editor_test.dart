import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/staff_product_editor_dialog.dart';
import 'package:myapp/services/store_service.dart';

const _product = StoreProduct(
  id: 'product-1',
  name: 'Linen Shirt',
  description: 'Lightweight linen shirt',
  imageUrl: 'https://example.com/shirt.jpg',
  price: 29.99,
  quantity: 8,
  isActive: true,
  category: 'Clothing',
  compareAtPrice: null,
  badge: '',
  availableSizes: ['S', 'M'],
  availableColors: ['Olive', 'Black'],
);

const _legacySaleProduct = StoreProduct(
  id: 'product-2',
  name: 'Cotton Tee',
  description: 'Soft cotton',
  imageUrl: 'https://example.com/tee.jpg',
  price: 490,
  quantity: 4,
  isActive: true,
  category: 'Clothing',
  compareAtPrice: 690,
  badge: 'SALE',
  availableSizes: ['S', 'M'],
  availableColors: ['White'],
);

void main() {
  testWidgets('editing and cancelling can be repeated without a widget error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<StaffProductDraft>(
                context: context,
                builder: (_) =>
                    const StaffProductEditorDialog(current: _product),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.text('Edit product'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Changed name');
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Edit product'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('saving returns validated product values', (tester) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) =>
                      const StaffProductEditorDialog(current: _product),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(saved?.name, 'Linen Shirt');
    expect(saved?.price, 29.99);
    expect(saved?.category, 'Clothing');
    expect(saved?.availableColors, ['Olive', 'Black']);
  });

  testWidgets('editing a product saves the selected category', (tester) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) =>
                      const StaffProductEditorDialog(current: _product),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bags').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.category, 'Bags');
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a product saves the selected category', (tester) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) => const StaffProductEditorDialog(),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Sandals');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Comfortable pair',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shoes').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'https://example.com/sandals.jpg',
    );
    await tester.enterText(find.byType(TextFormField).at(6), '2500');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Test Sandals');
    expect(saved?.category, 'Shoes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale switch calculates and saves the discounted price', (
    tester,
  ) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) =>
                      const StaffProductEditorDialog(current: _product),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(6), '2500');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(7), '10');
    await tester.pumpAndSettle();
    expect(find.textContaining('2,250.00'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.price, 2250);
    expect(saved?.compareAtPrice, 2500);
    expect(saved?.discountPercent, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('untouched older sale keeps its existing price', (tester) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) => const StaffProductEditorDialog(
                    current: _legacySaleProduct,
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.price, 490);
    expect(saved?.compareAtPrice, 690);
    expect(saved?.discountPercent, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning off a sale restores its regular price', (tester) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) => const StaffProductEditorDialog(
                    current: _legacySaleProduct,
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.price, 690);
    expect(saved?.compareAtPrice, isNull);
    expect(saved?.discountPercent, isNull);
    expect(saved?.badge, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new product can be created with a percentage sale', (
    tester,
  ) async {
    StaffProductDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<StaffProductDraft>(
                  context: context,
                  builder: (_) => const StaffProductEditorDialog(),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Sale Shirt');
    await tester.enterText(find.byType(TextFormField).at(1), 'Cotton shirt');
    await tester.enterText(
      find.byType(TextFormField).at(5),
      'https://example.com/shirt.jpg',
    );
    await tester.enterText(find.byType(TextFormField).at(6), '1500');
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(7), '20');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Sale Shirt');
    expect(saved?.price, 1200);
    expect(saved?.compareAtPrice, 1500);
    expect(saved?.discountPercent, 20);
    expect(tester.takeException(), isNull);
  });
}
