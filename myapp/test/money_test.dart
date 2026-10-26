import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/cart_items.dart';
import 'package:myapp/utils/money.dart';

void main() {
  test('formats catalog prices in Philippine pesos', () {
    expect(formatPeso(590), '₱590.00');
    expect(formatPeso(3490), '₱3,490.00');
  });

  test('keeps older orders in their original displayed currency', () {
    expect(formatOrderMoney(128, {}), '\$128.00');
    expect(formatOrderMoney(1990, {'currency': 'PHP'}), '₱1,990.00');
  });

  test('cart arithmetic accepts grouped peso prices', () {
    final line = CartLine(
      name: 'Blazer',
      description: '',
      price: formatPeso(2490),
      image: '',
      size: 'M',
      color: 'Black',
      quantity: 2,
    );
    expect(line.unitPrice, 2490);
    expect(line.total, 4980);
  });
}
