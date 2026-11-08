import 'store.dart';
import 'util.dart';

// ------------------------------------------------------------ date helpers (identical to the web app)
String addDays(String s, int n) {
  final d = parseDate(s);
  return isoDate(DateTime(d.year, d.month, d.day + n));
}

String addMonths(String s, int n) {
  final d = parseDate(s);
  final first = DateTime(d.year, d.month + n, 1);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return isoDate(DateTime(first.year, first.month, d.day < last ? d.day : last));
}

int daysIn(String ymKey) {
  final p = ymKey.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0).day;
}

int diffDays(String a, String b) => (parseDate(b).difference(parseDate(a)).inHours / 24).round();

String advanceDate(String d, String f) => f == 'daily'
    ? addDays(d, 1)
    : f == 'weekly'
        ? addDays(d, 7)
        : f == 'quarterly'
            ? addMonths(d, 3)
            : f == 'yearly'
                ? addMonths(d, 12)
                : addMonths(d, 1);

String retreatDate(String d, String f) => f == 'daily'
    ? addDays(d, -1)
    : f == 'weekly'
        ? addDays(d, -7)
        : f == 'quarterly'
            ? addMonths(d, -3)
            : f == 'yearly'
                ? addMonths(d, -12)
                : addMonths(d, -1);

/// [start, end] of the current budget period
(String, String) periodRange(String p, [String? ref]) {
  final t = ref ?? today();
  final d = parseDate(t);
  if (p == 'daily') return (t, t);
  if (p == 'weekly') {
    final s = addDays(t, -(d.weekday - 1));
    return (s, addDays(s, 6));
  }
  if (p == 'quarterly') {
    final q = ((d.month - 1) ~/ 3) * 3;
    return (isoDate(DateTime(d.year, q + 1, 1)), isoDate(DateTime(d.year, q + 4, 0)));
  }
  if (p == 'yearly') return ('${d.year}-01-01', '${d.year}-12-31');
  return (monthStart(ym(t)), monthEnd(ym(t)));
}

const kSubFreq = {'weekly': 'Weekly', 'monthly': 'Monthly', 'quarterly': 'Quarterly', 'yearly': 'Yearly'};
const kRecFreq = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly', 'yearly': 'Yearly'};
const kBudgetPeriods = {'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly', 'quarterly': 'Quarterly', 'yearly': 'Yearly'};

/// Round 3: budgets, subscriptions, recurring expenses, installments — same rules as the web app.
extension Round3Ops on AppStore {
  List<dynamic> get _tx => data['txns'] as List;
  List<dynamic> _raw(String k) {
    if (data[k] is! List) data[k] = <dynamic>[];
    return data[k] as List;
  }

  List<J> _l(String k) {
    if (data[k] is! List) data[k] = <dynamic>[];
    return (data[k] as List).whereType<Map>().map((e) => e as J).toList();
  }

  bool _inRange(J t, String f, String to) {
    final d = '${t['date']}';
    return d.compareTo(f) >= 0 && d.compareTo(to) <= 0;
  }

  List<String> catAndSubs(String id) => [id, ...categories.where((c) => c['parent'] == id).map((c) => '${c['id']}')];

  // ================================================================ budgets
  List<J> get budgets => _l('budgets');

  List<String> budgetCatIds(J b) => ((b['catIds'] as List?) ?? const []).map((e) => '$e').toList();

  List<J> budgetTxns(J b) {
    final (f, to) = periodRange('${b['period'] ?? 'monthly'}');
    final ids = budgetCatIds(b).expand(catAndSubs).toSet();
    return txns.where((t) => t['type'] == 'expense' && _inRange(t, f, to) && ids.contains('${t['catId']}')).toList();
  }

  double budgetSpent(J b) => budgetTxns(b).fold(0.0, (s, t) => s + tBase(t));

  void saveBudget({String? id, required String name, required double amount, required String period, required List<String> catIds}) {
    final r = <String, dynamic>{'name': name, 'amount': amount, 'period': period, 'catIds': catIds};
    if (id != null) {
      for (final b in budgets) {
        if (b['id'] == id) b.addAll(r);
      }
    } else {
      _raw('budgets').add({'id': uid(), ...r});
    }
    commit();
  }

  void deleteBudget(String id) {
    _raw('budgets').removeWhere((b) => b is Map && b['id'] == id);
    commit();
  }

  // ================================================================ subscriptions
  List<J> get subs => _l('subs');
  J? sub(String id) => subs.where((x) => x['id'] == id).firstOrNull;
  List<J> subPayments(J x) {
    if (x['payments'] is! List) x['payments'] = <dynamic>[];
    return (x['payments'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  double subMonthly(J x) {
    final a = toD(x['amount']);
    final f = '${x['freq']}';
    final m = f == 'weekly' ? a * 52 / 12 : f == 'quarterly' ? a / 3 : f == 'yearly' ? a / 12 : a;
    return conv(m, '${x['currency'] ?? base}', base);
  }

  void saveSub(J rec) {
    final list = _raw('subs');
    if (rec['id'] != null) {
      final x = sub('${rec['id']}');
      if (x != null) x.addAll(rec);
    } else {
      list.add({...rec, 'id': uid(), 'payments': <dynamic>[], 'active': rec['active'] ?? true});
    }
    commit();
  }

  void deleteSub(String id) {
    _raw('subs').removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  void toggleSub(String id) {
    final x = sub(id);
    if (x == null) return;
    x['active'] = x['active'] == false;
    commit();
  }

  /// Pay now: records an expense (kind "sub") and moves the next payment date on.
  void paySub({required String id, required String accId, required double amount, required String date, String? note, String? catId}) {
    final x = sub(id);
    if (x == null) return;
    final t = <String, dynamic>{
      'id': uid(),
      'type': 'expense',
      'kind': 'sub',
      'catId': catId ?? x['catId'] ?? _firstExpenseCat(),
      'accId': accId,
      'amount': round2(amount),
      'date': date,
      'time': nowTime(),
      'note': note ?? '${x['name']}',
      'tags': <dynamic>[],
      'receipt': null,
      'planId': null,
      'link': {'sub': id},
    };
    _tx.add(t);
    final pays = x['payments'] is List ? x['payments'] as List : (x['payments'] = <dynamic>[]) as List;
    pays.add({'id': uid(), 'date': date, 'amount': round2(amount), 'txId': t['id'], 'prevNext': x['next']});
    x['next'] = advanceDate('${x['next'] ?? today()}', '${x['freq'] ?? 'monthly'}');
    commit();
  }

  String? _firstExpenseCat() {
    for (final c in categories) {
      if (c['kind'] == 'expense') return '${c['id']}';
    }
    return null;
  }

  /// Remove one payment (and its transaction); puts the next date back when it was the latest.
  void deleteSubPayment(String sid, String pid) {
    final x = sub(sid);
    if (x == null) return;
    final pays = x['payments'] as List;
    final i = pays.indexWhere((p) => p is Map && p['id'] == pid);
    if (i < 0) return;
    final p = pays[i] as Map;
    final last = i == pays.length - 1;
    pays.removeAt(i);
    if (last) x['next'] = p['prevNext'] ?? retreatDate('${x['next']}', '${x['freq'] ?? 'monthly'}');
    if (p['txId'] != null) _tx.removeWhere((t) => t is Map && t['id'] == p['txId']);
    commit();
  }

  void editSubPayment(String sid, String pid, {required double amount, required String accId, required String date, required String note}) {
    final x = sub(sid);
    if (x == null) return;
    for (final p in subPayments(x)) {
      if (p['id'] != pid) continue;
      p['amount'] = round2(amount);
      p['date'] = date;
      J? t;
      for (final y in txns) {
        if (y['id'] == p['txId']) t = y;
      }
      if (t == null) {
        t = {'id': uid(), 'type': 'expense', 'kind': 'sub', 'catId': x['catId'] ?? _firstExpenseCat(), 'time': nowTime(), 'tags': <dynamic>[]};
        _tx.add(t);
        p['txId'] = t['id'];
      }
      t.addAll({'accId': accId, 'amount': round2(amount), 'date': date, 'note': note});
    }
    commit();
  }

  // ================================================================ recurring expenses
  List<J> get recurring => _l('recurring');
  J? rec(String id) => recurring.where((x) => x['id'] == id).firstOrNull;
  List<J> recPayments(J r) {
    if (r['payments'] is! List) r['payments'] = <dynamic>[];
    return (r['payments'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  String nextRecurring(J r, String from) {
    if (r['freq'] == 'monthly') {
      final d = addMonths('${from.substring(0, 8)}01', 1);
      final dom = int.tryParse('${r['dom']}') ?? 1;
      final k = ym(d);
      final day = dom < daysIn(k) ? dom : daysIn(k);
      return '${d.substring(0, 8)}${day.toString().padLeft(2, '0')}';
    }
    return advanceDate(from, '${r['freq']}');
  }

  String firstRecurring(J r) {
    final start = '${r['start'] ?? today()}';
    if (r['freq'] != 'monthly') return start;
    final k = ym(start);
    final dom = int.tryParse('${r['dom']}') ?? 1;
    var d = '$k-${(dom < daysIn(k) ? dom : daysIn(k)).toString().padLeft(2, '0')}';
    if (d.compareTo(start) < 0) d = nextRecurring(r, d);
    return d;
  }

  int recMissed(J r) {
    var n = 0;
    String? d = r['next']?.toString();
    final t = today();
    while (d != null && d.compareTo(t) < 0 && n < 999) {
      n++;
      d = nextRecurring(r, d);
    }
    return n;
  }

  void saveRec(J e) {
    final r = <String, dynamic>{...e, 'payments': e['payments'] ?? <dynamic>[], 'created': e['created'] ?? today()};
    r['next'] = firstRecurring(r);
    for (var i = 0; i < (r['payments'] as List).length; i++) {
      r['next'] = nextRecurring(r, '${r['next']}');
    }
    if (e['id'] != null) {
      rec('${e['id']}')?.addAll(r);
    } else {
      r['id'] = uid();
      _raw('recurring').add(r);
    }
    commit();
  }

  void deleteRec(String id) {
    _raw('recurring').removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  /// Make Payment: records the expense (kind "recurring") for the current due date and moves to the next one.
  void payRec({required String id, required String accId, required double amount, required String date, required String catId, String note = ''}) {
    final r = rec(id);
    if (r == null) return;
    final t = <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'recurring', 'catId': catId, 'accId': accId, 'amount': round2(amount), 'date': date, 'time': nowTime(), 'note': note, 'tags': <dynamic>['Recurring'], 'receipt': null, 'planId': null};
    _tx.add(t);
    final pays = r['payments'] is List ? r['payments'] as List : (r['payments'] = <dynamic>[]) as List;
    pays.add({'id': uid(), 'amount': round2(amount), 'date': date, 'accId': accId, 'txId': t['id'], 'due': r['next']});
    r['next'] = nextRecurring(r, '${r['next'] ?? today()}');
    commit();
  }

  void deleteRecPayment(String rid, String pid) {
    final r = rec(rid);
    if (r == null) return;
    final pays = r['payments'] as List;
    final i = pays.indexWhere((p) => p is Map && p['id'] == pid);
    if (i < 0) return;
    final p = pays[i] as Map;
    final last = i == pays.length - 1;
    pays.removeAt(i);
    if (last && p['due'] != null) r['next'] = p['due'];
    if (p['txId'] != null) _tx.removeWhere((t) => t is Map && t['id'] == p['txId']);
    commit();
  }

  // ================================================================ installments
  List<J> get installments => _l('installments');
  J? inst(String id) => installments.where((x) => x['id'] == id).firstOrNull;
  List<J> instPayments(J x) {
    if (x['payments'] is! List) x['payments'] = <dynamic>[];
    return (x['payments'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  int instCount(J x) => int.tryParse('${x['count']}') ?? (x['count'] is num ? (x['count'] as num).toInt() : 0);
  int instInitial(J x) => int.tryParse('${x['initialPaid'] ?? 0}') ?? 0;
  int instPaidCount(J x) => instInitial(x) + instPayments(x).length;
  double instPaidAmt(J x) => toD(x['advance']) + instInitial(x) * toD(x['amount']) + instPayments(x).fold(0.0, (s, p) => s + toD(p['amount']));
  double instRemain(J x) {
    final r = round2(toD(x['total']) - instPaidAmt(x));
    return r > 0 ? r : 0;
  }

  String? instNext(J x) {
    final n = instPaidCount(x);
    return n >= instCount(x) ? null : addMonths('${x['start']}', n);
  }

  (String, String) instStatus(J x) {
    final n = instPaidCount(x);
    if (n >= instCount(x) || instRemain(x) <= 0) return ('Completed', 'green');
    if (n > 0) return ('Partially Paid', 'blue');
    return ('Not Started', 'orange');
  }

  String? _catNamed(String n) {
    for (final c in categories) {
      if (c['name'] == n) return '${c['id']}';
    }
    return null;
  }

  void createInst({
    required String title,
    String lender = '',
    String? catId,
    required double total,
    double advance = 0,
    String? advAcc,
    required int count,
    double? amount,
    required String start,
    String? accId,
    int remindDays = 1,
    int initialPaid = 0,
  }) {
    final amt = (amount != null && amount > 0) ? amount : round2((total - advance) / count);
    final cid = catId ?? _catNamed('Shopping');
    if (advance > 0 && advAcc != null) {
      _tx.add({'id': uid(), 'type': 'expense', 'kind': 'inst', 'catId': cid, 'accId': advAcc, 'amount': round2(conv(advance, base, accCur(advAcc))), 'date': today(), 'time': nowTime(), 'note': '$title advance payment', 'tags': <dynamic>[]});
    }
    _raw('installments').add({
      'id': uid(),
      'advance': advance,
      'title': title,
      'lender': lender,
      'catId': cid,
      'total': total,
      'count': count,
      'amount': amt,
      'start': start,
      'freq': 'monthly',
      'accId': accId,
      'remindDays': remindDays,
      'initialPaid': initialPaid,
      'payments': <dynamic>[],
    });
    commit();
  }

  /// amount is in the main currency (like the web app); the expense is converted to the account currency
  void payInst({required String id, required double amount, required String accId, required String date}) {
    final x = inst(id);
    if (x == null) return;
    final t = <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'inst', 'catId': x['catId'], 'accId': accId, 'amount': round2(conv(amount, base, accCur(accId))), 'date': date, 'time': nowTime(), 'note': '${x['title']} installment ${instPaidCount(x) + 1}', 'tags': <dynamic>[]};
    _tx.add(t);
    final pays = x['payments'] is List ? x['payments'] as List : (x['payments'] = <dynamic>[]) as List;
    pays.add({'id': uid(), 'amount': amount, 'date': date, 'accId': accId, 'txId': t['id']});
    commit();
  }

  void deleteInstPayment(String iid, String pid) {
    final x = inst(iid);
    if (x == null) return;
    final pays = x['payments'] as List;
    final i = pays.indexWhere((p) => p is Map && p['id'] == pid);
    if (i < 0) return;
    final p = pays.removeAt(i) as Map;
    if (p['txId'] != null) _tx.removeWhere((t) => t is Map && t['id'] == p['txId']);
    commit();
  }

  void deleteInst(String id) {
    _raw('installments').removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  /// Where a linked transaction belongs (for the transaction details sheet).
  ({String kind, String id})? ownerOfTx(J t) {
    final id = t['id'];
    for (final x in subs) {
      if (subPayments(x).any((p) => p['txId'] == id)) return (kind: 'sub', id: '${x['id']}');
    }
    for (final r in recurring) {
      if (recPayments(r).any((p) => p['txId'] == id)) return (kind: 'rec', id: '${r['id']}');
    }
    for (final x in installments) {
      if (instPayments(x).any((p) => p['txId'] == id)) return (kind: 'inst', id: '${x['id']}');
    }
    return null;
  }
}
