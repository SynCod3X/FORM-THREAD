import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/customer_purchases_screen.dart';

void main() {
  Map<String, dynamic> order(
    String id, {
    String status = 'pending',
    String method = 'cash',
    String payment = 'cash_due',
  }) => {
    'id': '$id-0000-4000-8000-000000000001',
    'status': status,
    'payment_method': method,
    'payment_status': payment,
    'created_at': '2026-10-26T08:00:00Z',
    'total': 2300,
    'currency': 'PHP',
    'items': [
      {
        'name': 'Black Ankle Boots',
        'quantity': 1,
        'size': '10',
        'color': 'Black',
        'unit_price': 2300,
        'image': '',
      },
    ],
  };

  test('orders are grouped by customer-facing shopping stage', () {
    expect(
      purchaseTabFor(
        order('00000001', method: 'gcash', payment: 'awaiting_payment'),
      ),
      PurchaseTab.toPay,
    );
    expect(purchaseTabFor(order('00000002')), PurchaseTab.toShip);
    expect(
      purchaseTabFor(order('00000003', method: 'gcash', payment: 'paid')),
      PurchaseTab.toShip,
    );
    expect(
      purchaseTabFor(order('00000004', status: 'shipped')),
      PurchaseTab.toReceive,
    );
    expect(
      purchaseTabFor(order('00000005', status: 'completed')),
      PurchaseTab.completed,
    );
    expect(
      purchaseTabFor(order('00000006', status: 'cancelled')),
      PurchaseTab.cancelled,
    );
  });

  testWidgets('purchase tabs show the right orders on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(370, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final orders = [
      order('00000001', method: 'gcash', payment: 'awaiting_payment'),
      order('00000002', status: 'completed'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerPurchasesScreen(loadOrders: () async => orders),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORDER #00000001'), findsOneWidget);
    expect(find.text('ORDER #00000002'), findsOneWidget);
    expect(find.text('VIEW PAYMENT'), findsOneWidget);

    await tester.tap(find.text('To Pay'));
    await tester.pumpAndSettle();
    expect(find.text('ORDER #00000001'), findsOneWidget);
    expect(find.text('ORDER #00000002'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
