import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/ops.dart';
import 'package:salli_flutter/core/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = AppStore(await SharedPreferences.getInstance());
    s.data = jsonDecode(jsonEncode({
      'accounts': [
        {'id': 'mv', 'name': 'CBM MVR', 'currency': 'MVR', 'type': 'wallet'},
        {'id': 'lk', 'name': 'COM LKR', 'currency': 'LKR', 'type': 'wallet'},
      ],
      'txns': [],
      'categories': [
        {'id': 'b', 'name': 'Bank Charges', 'kind': 'expense', 'icon': '🏦', 'parent': null}
      ],
      'settings': {'base': 'LKR'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('transfer with own rate books exchange gain in receiving account', () {
    final app = s.rates.rateOf('MVR', 'LKR');
    s.doTransfer(from: 'mv', to: 'lk', amount: 1000, date: '2026-11-08', rate: app + 3, fee: 10);
    final lk = s.acc('lk')!;
    expect(s.accBal(lk), closeTo(1000 * (app + 3), 0.02));
    final gain = s.txns.firstWhere((t) => t['kind'] == 'fx_gain');
    expect((gain['amount'] as num).toDouble(), closeTo(3000, 0.02));
    expect(s.txns.where((t) => t['kind'] == 'bank_fee').length, 1);
    expect(s.accBal(s.acc('mv')!), -1010);
  });

  test('lower own rate books exchange loss; delete removes whole transfer', () {
    final app = s.rates.rateOf('MVR', 'LKR');
    s.doTransfer(from: 'mv', to: 'lk', amount: 100, date: '2026-11-08', rate: app - 1);
    expect(s.txns.any((t) => t['kind'] == 'fx_loss'), true);
    expect(s.accBal(s.acc('lk')!), closeTo(100 * (app - 1), 0.02));
    final g = s.transfers.first['group'] as String;
    s.deleteTransfer(g);
    expect(s.txns, isEmpty);
  });

  test('credit card add + available correction', () {
    s.saveCard(name: 'Visa', currency: 'LKR', limit: 150000, available: 120000, billingDay: 11, dueDay: 26, interest: 28, minPay: 5, includeCredit: true);
    final c = s.cards.first;
    expect(s.accBal(c), 120000);
    expect(s.cardUsed(c), 30000);
    s.saveCard(id: c['id'] as String, name: 'Visa', currency: 'LKR', limit: 150000, available: 100000, billingDay: 11, dueDay: 26, interest: 28, minPay: 5, includeCredit: true);
    expect(s.accBal(s.cards.first), 100000);
  });

  test('categories: duplicate names refused, delete promotes subcategories', () {
    expect(s.saveCategory(kind: 'expense', name: 'bank charges', icon: '🏦'), isNotNull);
    expect(s.saveCategory(kind: 'expense', name: 'Fees', icon: '💲', parent: 'b'), isNull);
    s.deleteCategory('b');
    expect(s.categories.single['parent'], isNull);
  });
}
