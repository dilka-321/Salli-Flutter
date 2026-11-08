import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/planning.dart';
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
        {'id': 'r', 'name': 'Rent', 'kind': 'expense', 'icon': '🏠', 'parent': null},
      ],
      'settings': {'base': 'LKR'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('monthly plan totals, spent and budgets created from it', () {
    final m = ym(today());
    final id = s.savePlan({
      'name': 'Nov',
      'month': m,
      'income': 200000,
      'incomeOrig': 200000,
      'incomeCur': 'LKR',
      'expenses': [
        {'catId': 'f', 'amount': 30000, 'orig': 30000, 'cur': 'LKR'},
        {'catId': 'r', 'amount': 50000, 'orig': 50000, 'cur': 'LKR'},
      ],
      'loans': [],
      'cards': [],
      'goals': [],
    }, createBudgets: true);
    final pl = s.mplan(id)!;
    expect(s.planTotal(pl), 80000);
    expect((s.data['budgets'] as List).length, 2);
    s.saveTx({'id': 'a', 'type': 'expense', 'kind': 'normal', 'catId': 'f', 'accId': 'lk', 'amount': 1200, 'date': today(), 'time': '10:00:00'});
    expect(s.planSpent(pl), 1200);
    expect(s.planOverview(pl).first.act, 1200);
  });

  test('spending plan stats and delete unlinks transactions', () {
    final id = s.saveSplan({'name': 'Trip', 'desc': '', 'start': today(), 'end': '', 'limit': 10000, 'planned': [
      {'id': 'p1', 'amount': 4000, 'catId': 'f', 'note': ''}
    ]});
    s.saveTx({'id': 'a', 'type': 'expense', 'kind': 'normal', 'catId': 'r', 'accId': 'lk', 'amount': 9500, 'date': today(), 'time': '10:00:00', 'planId': id});
    final st = s.splanStats(s.splan(id)!);
    expect(st.spent, 9500);
    expect(st.unplanned, 9500);
    expect(st.rem, 500);
    expect(st.mood.$1, 'Near limit');
    s.deleteSplan(id);
    expect(s.txns.single['planId'], isNull);
  });

  test('OT month: auto OT, no-pay and EPF like the web app', () {
    final c = s.otCfg;
    c['basic'] = 66000;
    c['workDays'] = 22;
    c['stdHours'] = 8;
    c['autoOT'] = true;
    c['allowances'] = [
      {'name': 'Travel', 'amount': 5000, 'epf': true}
    ];
    s.saveOtEntry(orig: '2026-10-01', date: '2026-10-01', inT: '08:00', outT: '18:00', otText: '', status: 'worked');
    s.saveOtEntry(orig: '2026-10-02', date: '2026-10-02', inT: '', outT: '', otText: '', status: 'nopay');
    final m = s.otMonth('2026-10');
    expect(m.ot, 2);
    expect(m.otRate, 562.5); // 66000 / (22*8) * 1.5
    expect(m.nopay, 3000);
    expect(m.gross, 66000 + 5000 + 2 * 562.5 - 3000);
    expect(m.epf, closeTo((66000 + 5000 - 3000) * 0.08, 0.001));
    expect(hrsBetween('22:00', '06:00'), 8);
  });
}
