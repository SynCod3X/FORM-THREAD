import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/checkout_screen.dart';

void main() {
  const orderId = '00000000-0000-4000-8000-000000000001';

  testWidgets('confirmation screen shows the stored paid status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          paymentMethod: 'gcash',
          loadOrder: (_) async => {'payment_status': 'paid'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAYMENT CONFIRMED'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('CONTINUE TO GCASH'), findsNothing);
    expect(find.text('Complete payment'), findsNothing);
  });

  testWidgets('customer can refresh a pending payment to confirmed', (
    tester,
  ) async {
    var paymentStatus = 'awaiting_payment';
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          paymentMethod: 'gcash',
          loadOrder: (_) async => {'payment_status': paymentStatus},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PAYMENT PENDING'), findsOneWidget);

    paymentStatus = 'paid';
    await tester.scrollUntilVisible(find.text('CHECK PAYMENT STATUS'), 150);
    await tester.tap(find.text('CHECK PAYMENT STATUS'));
    await tester.pumpAndSettle();

    expect(find.text('PAYMENT CONFIRMED'), findsOneWidget);
    expect(find.text('Payment confirmed'), findsOneWidget);
  });

  testWidgets('returning from checkout checks for webhook confirmation', (
    tester,
  ) async {
    var paymentStatus = 'awaiting_payment';
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          paymentMethod: 'gcash',
          autoCheckPayment: true,
          loadOrder: (_) async => {
            'payment_method': 'gcash',
            'payment_status': paymentStatus,
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('PAYMENT PENDING'), findsOneWidget);

    paymentStatus = 'paid';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('PAYMENT CONFIRMED'), findsOneWidget);
    expect(find.text('Complete payment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled order does not continue to show payment pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          paymentMethod: 'gcash',
          loadOrder: (_) async => {
            'status': 'cancelled',
            'payment_status': 'awaiting_payment',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORDER CANCELLED'), findsOneWidget);
    expect(find.text('Your order has been cancelled'), findsOneWidget);
    expect(find.text('CONTINUE TO GCASH'), findsNothing);
  });

  testWidgets('cash order confirmation reflects a cancelled order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          loadOrder: (_) async => {'status': 'cancelled'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORDER CANCELLED'), findsOneWidget);
    expect(find.text('Thank you for your order!'), findsNothing);
  });

  testWidgets('pending payment has a clear summary on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(370, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: OrderConfirmationScreen(
          orderId: orderId,
          paymentMethod: 'gcash',
          loadOrder: (_) async => {
            'status': 'pending',
            'payment_status': 'awaiting_payment',
            'total': 2300,
            'currency': 'PHP',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete your payment'), findsOneWidget);
    expect(find.text('₱2,300.00'), findsOneWidget);
    expect(find.text('GCash'), findsWidgets);
    expect(find.text('CONTINUE TO GCASH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
