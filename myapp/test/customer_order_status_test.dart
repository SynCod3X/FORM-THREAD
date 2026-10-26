import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/customer_orders_screen.dart';

void main() {
  test('approved cancellation is shown as cancelled to customers', () {
    expect(customerOrderRequestStatus('cancellation', 'approved'), 'Cancelled');
    expect(customerOrderRequestStatus('return', 'approved'), 'Approved');
  });
}
