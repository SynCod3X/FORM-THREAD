import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/payment_return_link.dart';

void main() {
  test('accepts only an order return link with a valid UUID', () {
    expect(
      PaymentReturnLink.orderId(
        Uri.parse(
          'formandthread://payment-return?order_id=051f28cc-e223-49dc-b0a3-672f359e80c5',
        ),
      ),
      '051f28cc-e223-49dc-b0a3-672f359e80c5',
    );
    expect(
      PaymentReturnLink.orderId(
        Uri.parse('formandthread://payment-return?order_id=not-an-order'),
      ),
      isNull,
    );
    expect(
      PaymentReturnLink.orderId(
        Uri.parse(
          'https://payment-return?order_id=051f28cc-e223-49dc-b0a3-672f359e80c5',
        ),
      ),
      isNull,
    );
  });
}
