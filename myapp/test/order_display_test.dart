import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/screens/customer_orders_screen.dart';

void main() {
  test('order statuses are readable to customers', () {
    expect(customerOrderStatus('in_progress'), 'In progress');
    expect(customerOrderStatus('completed'), 'Completed');
    expect(customerOrderStatus(''), 'Unknown');
  });
}
