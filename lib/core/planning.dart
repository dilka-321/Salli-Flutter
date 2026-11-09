import 'dart:math' as math;

import 'plans.dart';
import 'store.dart';
import 'util.dart';

/// One month of OT & Salary figures (same formulas as the web app).
class OtMonth {
  OtMonth({
    required this.n,
    required this.days,
    required this.ent,
    required this.cnt,
    required this.worked,
    required this.ot,
    required this.missing,
    required this.otRate,
    required this.allow,
    required this.ded,
    required this.allowSum,
    required this.otPay,
    required this.nopay,
    required this.gross,
    required this.epf,
    required this.etf,
    required this.dedSum,
    required this.net,
    required this.hourly,
  });
  final int n;
  final List<String> days, ent, missing;
  final Map<String, int> cnt;
  final double worked, ot, otRate, allowSum, otPay, nopay, gross, epf, etf, dedSum, net, hourly;
  final List<J> allow, ded;
}

const kOtStatus = {'worked': 'Worked', 'leave': 'Leave', 'nopay': 'No Pay', 'holiday': 'Holiday'};

double hrsBetween(String? a, String? b) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) return 0;
  final p1 = a.split(':'), p2 = b.split(':');
  var d = (int.parse(p2[0]) * 60 + int.parse(p2[1])) - (int.parse(p1[0]) * 60 + int.parse(p1[1]));
  if (d < 0) d += 1440;
  return d / 60;
}

/// Round 4: Monthly Plan, Spending Plan, OT & Salary — same data and rules as the web app.
extension Round4Ops on AppStore {
  List<dynamic> _r4(String k) {
    if (data[k] is! List) data[k] = <dynamic>[];
    return data[k] as List;
  }

  List<J> _l4(String k) => _r4(k).whereType<Map>().map((e) => e as J).toList();
  List<J> _items(J p, String k) {
    if (p[k] is! List) p[k] = <dynamic>[];
    return (p[k] as List).whereType<Map>().map((e) => e as J).toList();
  }

  double _sum(Iterable<J> l, double Function(J) f) => l.fold(0.0, (a, x) => a + f(x));
  bool _inR(String d, String f, String t) => d.compareTo(f) >= 0 && d.compareTo(t) <= 0;

  // ================================================================ loans / goals (read-only helpers used by plans)
  String lcur(J l) => '${l['currency'] ?? base}';
  double emiOf(J l) {
    final p = toD(l['principal']);
    final n = toD(l['months']) == 0 ? 1.0 : toD(l['months']);
    final r = toD(l['rate']) / 1200;
    if (r == 0) return p / n;
    return p * r * math.pow(1 + r, n) / (math.pow(1 + r, n) - 1);
  }

  double loanTotal(J l) => (toD(l['rate']) > 0 && toD(l['months']) > 0) ? emiOf(l) * toD(l['months']) : toD(l['principal']);
  double loanPaid(J l) => _items(l, 'payments').fold(0.0, (a, p) => a + toD(p['amount']));
  /// Remaining balance. A loan closed / settled manually counts as 0; "Reopen with Custom Balance" keeps an adjustment (remainAdj).
  double loanRemain(J l) => l['settled'] == true ? 0.0 : loanOpenRemain(l);
  double loanOpenRemain(J l) => math.max(0.0, round2(loanTotal(l) - loanPaid(l) - toD(l['remainAdj'])));
  double emiB(J l) => lconv(l, emiOf(l), lcur(l), base);

  List<J> get goals => _l4('goals');
  double goalSaved(J g) => _items(g, 'contributions').fold(0.0, (a, c) => a + toD(c['amount']));

  // ================================================================ monthly plans
  List<J> get mplans => _l4('plans');
  J? mplan(String id) => mplans.where((x) => x['id'] == id).firstOrNull;
  List<J> planItems(J p, String k) => _items(p, k);

  ({double exp, double loan, double card, double goal}) planAlloc(J p) => (
        exp: _sum(_items(p, 'expenses'), (x) => toD(x['amount'])),
        loan: _sum(_items(p, 'loans'), (x) => toD(x['amount'])),
        card: _sum(_items(p, 'cards'), (x) => toD(x['amount'])),
        goal: _sum(_items(p, 'goals'), (x) => toD(x['amount'])),
      );
  double planTotal(J p) {
    final a = planAlloc(p);
    return a.exp + a.loan + a.card + a.goal;
  }

  double catSpent(String catId, String f, String t) {
    final ids = catAndSubs(catId).toSet();
    return _sum(txns.where((x) => x['type'] == 'expense' && _inR('${x['date']}', f, t) && ids.contains('${x['catId']}')), tBase);
  }

  double planSpent(J p) {
    final f = monthStart('${p['month']}'), t = monthEnd('${p['month']}');
    final ids = _items(p, 'expenses').expand((x) => catAndSubs('${x['catId']}')).toSet();
    return _sum(txns.where((x) => x['type'] == 'expense' && _inR('${x['date']}', f, t) && (x['planId'] == p['id'] || ids.contains('${x['catId']}'))), tBase);
  }

  /// Plan vs. actual rows for the Monthly Overview: (section, icon, name, planned, actual)
  List<({String sec, String icon, String name, double plan, double act})> planOverview(J pl) {
    final f = monthStart('${pl['month']}'), t = monthEnd('${pl['month']}');
    final rows = <({String sec, String icon, String name, double plan, double act})>[];
    for (final x in _items(pl, 'expenses')) {
      final c = cat(x['catId']?.toString());
      rows.add((sec: 'Categories', icon: '${c?['icon'] ?? '📦'}', name: '${c?['name'] ?? 'Category'}', plan: toD(x['amount']), act: catSpent('${x['catId']}', f, t)));
    }
    for (final x in _items(pl, 'loans')) {
      final l = loans.where((y) => y['id'] == x['loanId']).firstOrNull;
      final act = l == null ? 0.0 : _sum(_items(l, 'payments').where((q) => _inR('${q['date']}', f, t)), (q) => lconv(l, toD(q['amount']), lcur(l), base));
      rows.add((sec: 'Loan Payments', icon: '🏦', name: '${l?['name'] ?? 'Loan'}', plan: toD(x['amount']), act: act));
    }
    for (final x in _items(pl, 'cards')) {
      final c = acc(x['accId']?.toString());
      final act = _sum(txns.where((q) => q['accId'] == x['accId'] && q['kind'] == 'transfer_in' && _inR('${q['date']}', f, t)), tBase);
      rows.add((sec: 'Credit Card Payments', icon: '💳', name: '${c?['name'] ?? 'Card'}', plan: toD(x['amount']), act: act));
    }
    for (final x in _items(pl, 'goals')) {
      final g = goals.where((y) => y['id'] == x['goalId']).firstOrNull;
      final act = g == null ? 0.0 : _sum(_items(g, 'contributions').where((q) => _inR('${q['date']}', f, t) && toD(q['amount']) > 0), (q) => toD(q['amount']));
      rows.add((sec: 'Saving Goals', icon: '${g?['icon'] ?? '🎯'}', name: '${g?['name'] ?? 'Goal'}', plan: toD(x['amount']), act: act));
    }
    return rows;
  }

  /// Saves a monthly plan. [createBudgets] also adds one monthly budget per expense category (new plans only).
  String savePlan(J rec, {bool createBudgets = false}) {
    final id = '${rec['id'] ?? uid()}';
    final r = {...rec, 'id': id};
    final old = mplan(id);
    if (old != null) {
      old.addAll(r);
    } else {
      _r4('plans').add(r);
      if (createBudgets) {
        for (final x in _items(r, 'expenses')) {
          _r4('budgets').add({'id': uid(), 'name': '${cat(x['catId']?.toString())?['name'] ?? 'Budget'}', 'amount': toD(x['amount']), 'period': 'monthly', 'catIds': <dynamic>['${x['catId']}']});
        }
      }
    }
    commit();
    return id;
  }

  void deletePlan(String id) {
    _r4('plans').removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  void setPlanIntroHide(bool v) {
    settings['planIntroHide'] = v;
    commit();
  }

  // ================================================================ spending plans
  List<J> get splans => _l4('splans');
  J? splan(String id) => splans.where((x) => x['id'] == id).firstOrNull;
  bool splanActive(J p) => '${p['start']}'.compareTo(today()) <= 0 && ('${p['end'] ?? ''}'.isEmpty || '${p['end']}'.compareTo(today()) >= 0);
  List<J> splanTxns(J p) => txns.where((t) => t['planId'] == p['id'] && t['type'] == 'expense').toList();

  ({List<J> tx, double planned, double spent, double unplanned, double limit, double cap, double rem, double ratio, (String, String, String, String) mood}) splanStats(J p) {
    final tx = splanTxns(p);
    final planned = _sum(_items(p, 'planned'), (x) => toD(x['amount']));
    final spent = _sum(tx, tBase);
    final pc = _items(p, 'planned').expand((x) => catAndSubs('${x['catId']}')).toSet();
    final unplanned = _sum(tx.where((t) => !pc.contains('${t['catId']}')), tBase);
    final limit = toD(p['limit']);
    final cap = limit != 0 ? limit : planned;
    final rem = cap - spent;
    final ratio = cap != 0 ? spent / cap : 0.0;
    final mood = ratio > 1
        ? ('Over budget', 'red', 'Your pocket hurts. Time to slow down', '😢')
        : ratio >= .9
            ? ('Near limit', 'orange', 'Careful — you are close to your limit', '😬')
            : ratio >= .25
                ? ('On budget', 'green', 'Your pocket feels okay', '😊')
                : ('Under Budget', 'green', 'Your pocket feels happy', '😍');
    return (tx: tx, planned: planned, spent: spent, unplanned: unplanned, limit: limit, cap: cap, rem: rem, ratio: ratio, mood: mood);
  }

  String saveSplan(J rec) {
    final id = '${rec['id'] ?? uid()}';
    final old = splan(id);
    if (old != null) {
      old.addAll({...rec, 'id': id});
    } else {
      _r4('splans').add({...rec, 'id': id, 'created': rec['created'] ?? today()});
    }
    commit();
    return id;
  }

  /// Deletes the plan; its transactions stay and are just unlinked (planId = null), like the web app.
  void deleteSplan(String id) {
    _r4('splans').removeWhere((x) => x is Map && x['id'] == id);
    for (final t in txns) {
      if (t['planId'] == id) t['planId'] = null;
    }
    commit();
  }

  void addPlanned(String id, J x) {
    final p = splan(id);
    if (p == null) return;
    if (p['planned'] is! List) p['planned'] = <dynamic>[];
    (p['planned'] as List).add(x);
    commit();
  }

  void removePlanned(String id, String xid) {
    final p = splan(id);
    if (p == null) return;
    (p['planned'] as List).removeWhere((x) => x is Map && x['id'] == xid);
    commit();
  }

  // ================================================================ OT & salary
  J get ot {
    if (data['ot'] is! Map) {
      data['ot'] = <String, dynamic>{
        'cfg': <String, dynamic>{
          'basic': 0, 'otRate': 0, 'workDays': 22, 'stdHours': 8, 'autoOT': false, 'epf': 8, 'etf': 3,
          'allowances': <dynamic>[
            <String, dynamic>{'name': '', 'amount': 0, 'epf': false},
            <String, dynamic>{'name': '', 'amount': 0, 'epf': false},
          ],
          'deductions': <dynamic>[
            <String, dynamic>{'name': '', 'amount': 0}
          ],
        },
        'log': <String, dynamic>{},
      };
    }
    final o = data['ot'] as J;
    if (o['cfg'] is! Map) o['cfg'] = <String, dynamic>{};
    if (o['log'] is! Map) o['log'] = <String, dynamic>{};
    final c = o['cfg'] as J;
    if (c['allowances'] is! List) c['allowances'] = <dynamic>[];
    if (c['deductions'] is! List) c['deductions'] = <dynamic>[];
    return o;
  }

  J get otCfg => ot['cfg'] as J;
  J get otLog => ot['log'] as J;
  J? otEntry(String d) => otLog[d] is Map ? otLog[d] as J : null;

  double otAuto(String? inT, String? outT) => math.max(0.0, hrsBetween(inT, outT) - toD(otCfg['stdHours']));

  OtMonth otMonth(String k) {
    final c = otCfg, log = otLog;
    final n = daysIn(k);
    final tk = ym(today());
    final last = k == tk ? parseDate(today()).day : (k.compareTo(tk) < 0 ? n : 0);
    final days = List.generate(n, (i) => '$k-${(i + 1).toString().padLeft(2, '0')}');
    final ent = days.where((d) => log[d] is Map).toList();
    final cnt = <String, int>{'worked': 0, 'leave': 0, 'nopay': 0, 'holiday': 0};
    for (final d in ent) {
      final s = '${(log[d] as Map)['status'] ?? 'worked'}';
      cnt[s] = (cnt[s] ?? 0) + 1;
    }
    J e(String d) => log[d] as J;
    final worked = ent.where((d) => e(d)['status'] == 'worked').fold(0.0, (a, d) => a + hrsBetween(e(d)['in']?.toString(), e(d)['out']?.toString()));
    final std = toD(c['stdHours']);
    final otH = ent.fold(0.0, (a, d) {
      final x = e(d);
      if (c['autoOT'] == true && x['status'] == 'worked' && '${x['in'] ?? ''}'.isNotEmpty && '${x['out'] ?? ''}'.isNotEmpty) {
        return a + math.max(0.0, hrsBetween('${x['in']}', '${x['out']}') - std);
      }
      return a + toD(x['ot']);
    });
    final missing = days.take(last).where((d) => log[d] is! Map).toList();
    final basic = toD(c['basic']), wd = toD(c['workDays']);
    final hourly = basic != 0 && wd != 0 && std != 0 ? basic / (wd * std) : 0.0;
    final otRate = toD(c['otRate']) != 0 ? toD(c['otRate']) : round2(hourly * 1.5);
    final allow = (c['allowances'] as List).whereType<Map>().map((x) => x as J).where((x) => '${x['name'] ?? ''}'.isNotEmpty || toD(x['amount']) != 0).toList();
    final ded = (c['deductions'] as List).whereType<Map>().map((x) => x as J).where((x) => '${x['name'] ?? ''}'.isNotEmpty || toD(x['amount']) != 0).toList();
    final allowSum = _sum(allow, (x) => toD(x['amount']));
    final otPay = otH * otRate;
    final nopay = wd != 0 ? basic / wd * (cnt['nopay'] ?? 0) : 0.0;
    final gross = basic + allowSum + otPay - nopay;
    final epfBase = basic + _sum(allow.where((x) => x['epf'] == true), (x) => toD(x['amount'])) - nopay;
    final epf = epfBase * toD(c['epf']) / 100, etf = epfBase * toD(c['etf']) / 100;
    final dedSum = _sum(ded, (x) => toD(x['amount']));
    return OtMonth(
      n: n, days: days, ent: ent, cnt: cnt, worked: worked, ot: otH, missing: missing, otRate: otRate, allow: allow, ded: ded,
      allowSum: allowSum, otPay: otPay, nopay: nopay, gross: gross, epf: epf, etf: etf, dedSum: dedSum, net: gross - epf - dedSum, hourly: hourly,
    );
  }

  void saveOtEntry({required String orig, required String date, required String inT, required String outT, required String otText, required String status}) {
    final auto = otCfg['autoOT'] == true && inT.isNotEmpty && outT.isNotEmpty ? otAuto(inT, outT) : null;
    if (orig != date) otLog.remove(orig);
    otLog[date] = <String, dynamic>{'in': inT, 'out': outT, 'ot': otText.trim().isNotEmpty ? (double.tryParse(otText.trim()) ?? 0) : (auto ?? 0), 'status': status};
    commit();
  }

  void deleteOtEntry(String d) {
    otLog.remove(d);
    commit();
  }

  void saveOtCfg() => commit();
}
