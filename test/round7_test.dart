import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/export.dart';
import 'package:salli_flutter/core/round7.dart';
import 'package:salli_flutter/core/store.dart';
import 'package:salli_flutter/core/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppStore s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = AppStore(await SharedPreferences.getInstance());
    s.data = jsonDecode(jsonEncode({
      'accounts': [
        {'id': 'boc', 'name': 'BOC Savings', 'currency': 'LKR', 'type': 'wallet'},
      ],
      'txns': [
        {'id': 'a', 'type': 'expense', 'kind': 'normal', 'catId': 'g', 'accId': 'boc', 'amount': 1200, 'date': today(), 'time': '10:00:00', 'note': 'Keells'},
      ],
      'categories': [
        {'id': 'g', 'name': 'Groceries', 'kind': 'expense', 'icon': '🛒', 'parent': null},
        {'id': 'o', 'name': 'Other', 'kind': 'expense', 'icon': '📦', 'parent': null},
        {'id': 's', 'name': 'Salary', 'kind': 'income', 'icon': '💵', 'parent': null},
      ],
      'settings': {'base': 'LKR', 'name': 'Dilka'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('PIN hash matches the web app', () {
    expect(pinHash('1234'), 'hjzqsym');
    expect(pinHash('0000'), 'hjzpzh0');
  });

  test('SMS parser: debit, salary credit, OTP and promo skipped', () {
    final (ok, sk) = s.addSmsDrafts('BOC: LKR 3,450.00 debited from A/C XXXX4521 at KEELLS SUPER on 01/01. Avl Bal LKR 52,310.00\n\nYour OTP is 482910. Do not share.\n\nLKR 145,000.00 credited SALARY from ABC PVT LTD.\n\nMEGA SALE! 40% off. Click to claim.');
    expect(ok, 2);
    expect(sk, containsAll(['OTP', 'Promotion']));
    final d = s.smsDrafts.first;
    expect(d['amount'], 3450);
    expect(d['type'], 'expense');
    expect(d['catId'], 'g');
    expect(d['accId'], 'boc');
    expect('${d['raw']}'.contains('4521'), isFalse);
    expect(s.smsDrafts[1]['type'], 'income');
    expect(s.saveAllSmsDrafts(), 2);
    expect(s.txns.length, 3);
  });

  test('backup round trip', () {
    final j = s.backupJson();
    final (d, at) = s.parseBackup(j);
    expect(at, isNotNull);
    s.eraseAll();
    expect(s.txns, isEmpty);
    s.restoreBackup(d);
    expect(s.txns.single['note'], 'Keells');
    expect(() => s.parseBackup('{"hello":1}'), throwsA(isA<String>()));
  });

  test('report exports build', () async {
    final m = ym(today());
    final x = buildReportXlsx(s, monthStart(m), monthEnd(m));
    expect(String.fromCharCodes(x.take(2)), 'PK');
    final pdf = await buildReportPdf(s, monthStart(m), monthEnd(m));
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(latin('🛒 Rs 1,200 – €5'), 'Rs 1,200 - EUR 5');
  });

  test('manual rate and notifications', () {
    s.saveRate(null, 'USD', 'LKR', 305);
    expect(s.rates.rateOf('USD', 'LKR'), closeTo(305, .001));
    s.saveRate(null, 'LKR', 'USD', 1 / 310);
    expect(s.manualRates.length, 1);
    s.addSmsDrafts('LKR 500.00 debited at CAFE on 01/01');
    expect(s.notifications().first.scr, 'sms');
  });
}
