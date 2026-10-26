import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/sale_pricing.dart';

void main() {
  test('discount produces a peso sale price rounded to cents', () {
    expect(calculateSalePrice(2500, 10), 2250);
    expect(calculateSalePrice(999, 12.5), 874.13);
    expect(calculateSalePrice(1, 50), 0.5);
  });

  test('invalid amounts and percentages are rejected', () {
    expect(calculateSalePrice(100, 0), isNull);
    expect(calculateSalePrice(100, 100), isNull);
    expect(calculateSalePrice(0, 10), isNull);
    expect(calculateSalePrice(100, 10.001), isNull);
    expect(calculateSalePrice(0.01, 99), isNull);
    expect(calculateSalePrice(1, 0.01), isNull);
  });
}
