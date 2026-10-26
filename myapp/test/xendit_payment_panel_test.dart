import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/xendit_payment_panel.dart';

void main() {
  testWidgets('GCash is pending until a verified callback updates the order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XenditPaymentPanel(
            orderId: '00000000-0000-4000-8000-000000000001',
            paymentMethod: 'gcash',
            paymentStatus: 'awaiting_payment',
          ),
        ),
      ),
    );
    expect(find.text('GCash'), findsOneWidget);
    expect(find.textContaining('Payment pending.'), findsOneWidget);
    expect(find.text('CONTINUE TO GCASH'), findsOneWidget);
    expect(find.text('Xendit test mode'), findsNothing);
    expect(find.text('Payment confirmed.'), findsNothing);
  });

  testWidgets('bank transfer displays the virtual account supplied by Xendit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XenditPaymentPanel(
            orderId: '00000000-0000-4000-8000-000000000001',
            paymentMethod: 'bank_transfer',
            paymentStatus: 'awaiting_payment',
            action: {
              'type': 'PRESENT_TO_CUSTOMER',
              'descriptor': 'VIRTUAL_ACCOUNT_NUMBER',
              'value': '7057601478328965',
            },
          ),
        ),
      ),
    );
    expect(find.text('7057601478328965'), findsOneWidget);
    expect(find.text('Test account — do not send real funds.'), findsOneWidget);
  });

  testWidgets('cancelled order cannot restart an online checkout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: XenditPaymentPanel(
            orderId: '00000000-0000-4000-8000-000000000001',
            paymentMethod: 'gcash',
            paymentStatus: 'awaiting_payment',
            orderStatus: 'cancelled',
            action: {
              'type': 'REDIRECT_CUSTOMER',
              'descriptor': 'WEB_URL',
              'value': 'https://example.test/checkout',
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('Order cancelled.'), findsOneWidget);
    expect(find.text('OPEN GCASH CHECKOUT'), findsNothing);
    expect(find.text('CONTINUE TO GCASH'), findsNothing);
  });
}
