import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      ],
      'txns': [],
      'categories': [
        {'id': 'f', 'name': 'Food', 'kind': 'expense', 'icon': '🍕', 'parent': null},
        {'id': 'f2', 'name': 'Snacks', 'kind': 'expense', 'icon': '🍪', 'parent': 'f'},
        {'id': 'sh', 'name': 'Shopping', 'kind': 'expense', 'icon': '🛍️', 'parent': null},
      ],
      'settings': {'base': 'LKR'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('date helpers match the web app', () {
    expect(addMonths('2026-01-31', 1), '2026-02-28');
    expect(addMonths('2026-03-15', -3), '2025-12-15');
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(advanceDate('2026-11-08', 'quarterly'), '2027-02-08');
    expect(periodRange('weekly', '2026-11-08'), ('2026-11-02', '2026-11-08'));
    expect(periodRange('quarterly', '2026-11-08'), ('2026-10-01', '2026-12-31'));
    expect(diffDays('2026-11-08', '2026-11-30'), 22);
  });

  test('budget counts expenses in its categories and subcategories this period', () {
    s.saveBudget(name: 'Food', amount: 1000, period: 'monthly', catIds: ['f']);
    s.saveTx({'id': 'a', 'type': 'expense', 'kind': 'normal', 'catId': 'f2', 'accId': 'lk', 'amount': 300, 'date': today(), 'time': '10:00:00'});
    s.saveTx({'id': 'b', 'type': 'expense', 'kind': 'normal', 'catId': 'sh', 'accId': 'lk', 'amount': 500, 'date': today(), 'time': '10:00:00'});
    expect(s.budgetSpent(s.budgets.first), 300);
  });

  test('subscription pay advances next date; deleting the payment puts it back', () {
    s.saveSub({'name': 'Netflix', 'amount': 1500, 'currency': 'LKR', 'freq': 'monthly', 'start': '2026-10-05', 'next': '2026-11-05', 'catId': 'f'});
    final id = '${s.subs.first['id']}';
    s.paySub(id: id, accId: 'lk', amount: 1500, date: '2026-11-05');
    expect(s.sub(id)!['next'], '2026-12-05');
    expect(s.txns.single['kind'], 'sub');
    expect(s.ownerOfTx(s.txns.single)!.kind, 'sub');
    final pid = '${s.subPayments(s.sub(id)!).single['id']}';
    s.editSubPayment(id, pid, amount: 1600, accId: 'lk', date: '2026-11-06', note: 'x');
    expect(s.txns.single['amount'], 1600);
    s.deleteSubPayment(id, pid);
    expect(s.sub(id)!['next'], '2026-11-05');
    expect(s.txns, isEmpty);
  });

  test('recurring monthly uses day of month and counts missed periods', () {
    s.saveRec({'title': 'Rent', 'amount': 50000, 'catId': 'f', 'freq': 'monthly', 'dom': 31, 'start': '2026-01-10', 'accId': 'lk'});
    final r = s.recurring.first;
    expect(r['next'], '2026-01-31');
    expect(s.nextRecurring(r, '2026-01-31'), '2026-02-28');
    expect(s.recMissed(r), greaterThan(0));
    s.payRec(id: '${r['id']}', accId: 'lk', amount: 50000, date: '2026-02-01', catId: 'f');
    expect(s.rec('${r['id']}')!['next'], '2026-02-28');
    expect(s.txns.single['kind'], 'recurring');
  });

  test('installment wizard math, payment and status', () {
    s.createInst(title: 'Phone', total: 120000, advance: 20000, advAcc: 'lk', count: 10, start: '2026-12-01', accId: 'lk', initialPaid: 2);
    final x = s.installments.first;
    expect(x['amount'], 10000);
    expect(s.txns.single['note'], 'Phone advance payment');
    expect(s.instPaidCount(x), 2);
    expect(s.instRemain(x), 80000);
    expect(s.instNext(x), '2027-02-01');
    expect(s.instStatus(x).$1, 'Partially Paid');
    s.payInst(id: '${x['id']}', amount: 10000, accId: 'lk', date: '2026-12-01');
    expect(s.instRemain(x), 70000);
    expect(s.txns.last['note'], 'Phone installment 3');
  });
}
