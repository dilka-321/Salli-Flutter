import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/currency.dart';

void main() {
  test('money format matches the web app', () {
    expect(money(1234.5, 'LKR'), 'Rs 1,234.50');
    expect(money(-20, 'MVR'), '-Rf 20.00');
  });

  test('cross rate through USD', () {
    final r = Rates([], null);
    expect(r.rateOf('USD', 'LKR'), 300);
    expect(r.rateOf('LKR', 'LKR'), 1);
  });
}
