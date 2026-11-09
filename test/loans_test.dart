import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/loans.dart';
import 'package:salli_flutter/core/planning.dart';
import 'package:salli_flutter/core/plans.dart';
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
        {'id': 'lk', 'name': 'COM LKR', 'currency': 'LKR', 'type': 'wallet'},
        {'id': 'mv', 'name': 'CBM MVR', 'currency': 'MVR', 'type': 'wallet'},
      ],
      'txns': [],
      'categories': [
        {'id': 'bc', 'name': 'Bank Charges', 'kind': 'expense', 'icon': '🏦', 'parent': null},
        {'id': 'in', 'name': 'Interest', 'kind': 'income', 'icon': '🪙', 'parent': null},
      ],
      'settings': {'base': 'LKR'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('loan with agreed rate: received amount, payment, fee, delete', () {
    // 1 MVR = 18 LKR agreed (stored as units of LKR per 1 MVR)
    final id = s.saveLoan(name: 'Shali', type: 'personal', lender: '', currency: 'MVR', principal: 1000, rate: 0, months: 0, start: today(), rates: {'LKR': 18}, rateDir: {'LKR': false}, accId: 'mv');
    final l = s.loan(id)!;
    expect(s.txns.single['kind'], 'loan_receive');
    expect(s.txns.single['amount'], 1000);
    expect(s.loanRemainB(l), 18000);
    s.payLoan(id, v: 9000, cur: 'LKR', fee: 100, accId: 'lk', date: today(), note: 'x');
    expect(s.loanPaid(l), 500); // 9000 LKR / 18
    expect(s.txns.where((t) => t['kind'] == 'bank_fee').single['catId'], 'bc');
    final pid = '${s.loanPayments(l).single['id']}';
    s.editLoanPayment(id, pid, v: 18000, fee: 0, accId: 'lk', date: today(), note: 'y');
    expect(s.loanRemain(l), 0);
    expect(s.txns.where((t) => t['kind'] == 'bank_fee'), isEmpty);
    expect(s.loanLinkOfTx(s.txns.first)!.kind, 'loan');
    s.removeLoan(id);
    expect(s.txns, isEmpty);
    expect(s.loans, isEmpty);
  });

  test('loan overdue and schedule', () {
    final id = s.saveLoan(name: 'Bank', type: 'bank', lender: 'BOC', currency: 'LKR', principal: 120000, rate: 12, months: 12, start: addMonths(today(), -2), rates: {}, rateDir: {});
    final l = s.loan(id)!;
    expect(s.loanSchedule(l).length, 12);
    expect(s.loanOverdue(l)!.k, 1);
    expect(s.dueItems().any((d) => d.scr == 'loan'), isTrue);
  });

  test('lending give / receive / remove', () {
    final id = s.saveLending(name: 'Ali', currency: 'LKR', amount: 5000, accId: 'lk', due: addMonths(today(), 1), note: '');
    final x = s.lending(id)!;
    expect(s.txns.single['kind'], 'lend_give');
    s.receiveLending(id, v: 2000, cur: 'LKR', accId: 'lk', date: today(), note: '');
    expect(s.lendRemain(x), 3000);
    s.removeLending(id);
    expect(s.txns, isEmpty);
  });

  test('fixed deposit posts monthly interest once', () {
    final types = s.assetTypes;
    final fdType = types.firstWhere((t) => t['fd'] == true);
    final n = s.saveAsset(name: 'BOC FD', typeId: '${fdType['id']}', value: 120000, note: '', fd: {'currency': 'LKR', 'rate': 12, 'basis': 'yearly', 'start': addMonths(today(), -3), 'months': 12, 'payout': 'monthly', 'accId': 'lk'});
    expect(n, 3);
    expect(s.txns.first['amount'], 1200);
    expect(s.runFDInterest(), 0);
    final nw = s.netWorthDetail();
    expect(nw.A, closeTo(120000 + 3600, .01));
  });

  test('close / manual override: settle and reopen with a custom balance', () {
    final id = s.saveLoan(name: 'Nipun', type: 'personal', lender: '', currency: 'LKR', principal: 1000, rate: 0, months: 0, start: today(), rates: {}, rateDir: {}, accId: 'lk');
    final l = s.loan(id)!;
    expect(s.loanRemain(l), 1000);
    s.settleLoan(id, mode: 'closed');
    expect(s.loanRemain(l), 0);
    s.reopenLoan(id, 400);
    expect(s.loanRemain(l), 400);
    s.payLoan(id, v: 100, cur: 'LKR', fee: 0, accId: 'lk', date: today(), note: 'x');
    expect(s.loanRemain(l), 300);
  });
}
