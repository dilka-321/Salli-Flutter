import 'dart:math' as math;

import 'currency.dart';
import 'ops.dart';
import 'planning.dart';
import 'plans.dart';
import 'store.dart';
import 'util.dart';

const kAssetGroups = ['Cash', 'Bank', 'Lending', 'Fixed Assets', 'Saving Goals', 'Investment'];
const kLiabGroups = ['Credit Card', 'Loan', 'Installment', 'Other Liability'];
const _defGroup = {
  'Bank': 'Bank', 'Cash': 'Cash', 'Emergency Fund': 'Saving Goals', 'Investment': 'Investment', 'Fixed Deposit': 'Investment', 'Gold': 'Fixed Assets',
  'Property': 'Fixed Assets', 'Vehicle': 'Fixed Assets', 'Lending': 'Lending', 'Bank Loan': 'Loan', 'Personal Loan': 'Loan', 'Credit Card': 'Credit Card',
  'Installment Plan': 'Installment',
};

class LoanRow {
  LoanRow(this.k, this.d, this.it, this.pr, this.bal);
  final int k;
  final String d;
  final double it, pr, bal;
}

class DueItem {
  DueItem({required this.key, required this.id, required this.scr, required this.name, required this.amt, required this.days, required this.kind});
  final String key, id, scr, name, amt, kind;
  final int days;
}

class NwGroup {
  NwGroup(this.name);
  final String name;
  final items = <({String name, double v})>[];
  double v = 0;
}

class NetWorth {
  NetWorth({required this.A, required this.L, required this.groups, required this.lgroups, required this.ratio, required this.ins, required this.chA, required this.chL});
  final double A, L, ratio, chA, chL;
  double get net => A - L;
  final List<NwGroup> groups, lgroups;
  final List<({String icon, String color, String text})> ins;
}

/// Round 5: loans (agreed rates, overdue), lendings, assets & fixed deposits, net worth, Due Soon — same rules as the web app.
extension Round5Ops on AppStore {
  List<dynamic> _r5(String k) {
    if (data[k] is! List) data[k] = <dynamic>[];
    return data[k] as List;
  }

  List<J> _l5(String k) => _r5(k).whereType<Map>().map((e) => e as J).toList();
  List<J> _pays(J x) {
    if (x['payments'] is! List) x['payments'] = <dynamic>[];
    return (x['payments'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  void _dropTx(Set<String> ids) => (data['txns'] as List).removeWhere((t) => t is Map && ids.contains('${t['id']}'));
  J? _tx(dynamic id) => id == null ? null : txns.where((t) => t['id'] == id).firstOrNull;
  String? get _bankChargesCat => categories.where((c) => c['name'] == 'Bank Charges').firstOrNull?['id']?.toString();

  // ================================================================ loans
  J? loan(String id) => loans.where((l) => l['id'] == id).firstOrNull;
  List<J> loanPayments(J l) => _pays(l);
  double loanRemainB(J l) => lconv(l, loanRemain(l), lcur(l), base);
  bool hasTenure(J l) => toD(l['months']) > 0;

  J? loanRecvTx(J l) =>
      txns.where((t) => t['kind'] == 'loan_receive' && t['link'] is Map && (t['link'] as Map)['loan'] == l['id']).firstOrNull ??
      txns.where((t) => t['kind'] == 'loan_receive' && !(t['link'] is Map && (t['link'] as Map)['loan'] != null) && t['who'] == l['name']).firstOrNull;

  J? loanFeeTx(J l, J p) => p['feeTxId'] != null
      ? _tx(p['feeTxId'])
      : txns.where((t) => t['kind'] == 'bank_fee' && t['who'] == l['name'] && t['date'] == p['date'] && t['accId'] == p['accId'] && t['note'] == 'Bank fee for loan payment').firstOrNull;

  /// next unpaid instalment that is already past due: (number, date, days overdue)
  ({int k, String d, int days})? loanOverdue(J l) {
    final m = toD(l['months']).toInt();
    if (m <= 0 || loanRemain(l) <= 0) return null;
    final k = math.min(_pays(l).length, m) + 1;
    if (k > m) return null;
    final d = addMonths('${l['start']}', k - 1);
    final t = today();
    if (d.compareTo(t) >= 0) return null;
    return (k: k, d: d, days: diffDays(d, t));
  }

  List<LoanRow> loanSchedule(J l) {
    final rows = <LoanRow>[];
    if (!hasTenure(l)) return rows;
    var bal = toD(l['principal']);
    final rr = toD(l['rate']) / 1200, e = emiOf(l);
    for (var k = 1; k <= toD(l['months']).toInt(); k++) {
      final it = bal * rr, pr = e - it;
      bal = math.max(0.0, bal - pr);
      rows.add(LoanRow(k, addMonths('${l['start']}', k - 1), it, pr, bal));
    }
    return rows;
  }

  /// Agreed-rate display: "1 X = r Y" (inverted when that reads better / was entered that way).
  bool loanRateInv(J l, String k) {
    final d = l['rateDir'];
    if (d is Map && d[k] != null) return d[k] == true;
    return !fxStrong(lcur(l), k);
  }

  /// Add or edit a loan. [rates] are stored as "units of CUR per 1 loan currency" + [rateDir] (exactly like the web app).
  String saveLoan({
    String? id,
    required String name,
    required String type,
    required String lender,
    required String currency,
    required double principal,
    required double rate,
    required int months,
    required String start,
    required Map<String, double> rates,
    required Map<String, bool> rateDir,
    String? accId,
  }) {
    final f = <String, dynamic>{
      'name': name, 'type': type, 'lender': lender, 'currency': currency, 'principal': principal, 'rate': rate, 'months': months, 'start': start,
      'rates': <String, dynamic>{...rates}, 'rateDir': <String, dynamic>{...rateDir},
    };
    if (id != null) {
      final l = loan(id)!;
      final oldP = toD(l['principal']), oldCur = lcur(l);
      final rt = loanRecvTx(l);
      l.addAll(f);
      if (rt != null) {
        final ac = accCur(rt['accId']?.toString());
        final amt = ac == currency
            ? principal
            : rates[ac] != null
                ? round2(lconv(l, principal, currency, ac))
                : oldCur == currency && oldP > 0
                    ? round2(toD(rt['amount']) * principal / oldP)
                    : round2(conv(principal, currency, ac));
        rt.addAll({'who': name, 'amount': amt, 'note': 'Loan received: $name${currency != ac ? ' (${money(principal, currency)})' : ''}', 'link': <String, dynamic>{'loan': id}});
      }
      commit();
      return id;
    }
    final l = <String, dynamic>{'id': uid(), ...f, 'accId': accId, 'payments': <dynamic>[]};
    _r5('loans').add(l);
    if (accId != null) {
      final ac = accCur(accId);
      (data['txns'] as List).add(<String, dynamic>{
        'id': uid(), 'type': 'income', 'kind': 'loan_receive', 'who': name, 'accId': accId, 'amount': round2(lconv(l, principal, currency, ac)), 'date': today(),
        'time': nowTime(), 'note': 'Loan received: $name${currency != ac ? ' (${money(principal, currency)})' : ''}', 'tags': <dynamic>[], 'link': <String, dynamic>{'loan': l['id']},
      });
    }
    commit();
    return '${l['id']}';
  }

  /// Deletes a loan with every transaction it created (received amount, repayments, bank fees).
  void removeLoan(String id) {
    final l = loan(id);
    if (l == null) return;
    final ids = <String>{};
    final rt = loanRecvTx(l);
    if (rt != null) ids.add('${rt['id']}');
    for (final p in _pays(l)) {
      if (p['txId'] != null) ids.add('${p['txId']}');
      final f = loanFeeTx(l, p);
      if (f != null) ids.add('${f['id']}');
    }
    _dropTx(ids);
    (data['loans'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  /// Close Loan / Manual Override → mark the loan as paid without recording a payment.
  void settleLoan(String id, {String mode = 'manual'}) {
    final l = loan(id);
    if (l == null) return;
    l['settled'] = true;
    l['settledAt'] = today();
    l['settleMode'] = mode;
    commit();
  }

  /// Manual Override → set a custom remaining principal and mark the loan as active again.
  void reopenLoan(String id, double remaining) {
    final l = loan(id);
    if (l == null) return;
    l.remove('settled');
    l.remove('settledAt');
    l.remove('settleMode');
    l['remainAdj'] = round2(loanTotal(l) - loanPaid(l) - remaining);
    commit();
  }

  /// Pay now: [v] in [cur]; money leaves [accId] (converted with the loan's agreed rate).
  void payLoan(String id, {required double v, required String cur, required double fee, required String accId, required String date, required String note}) {
    final l = loan(id)!;
    _pays(l);
    final c = lcur(l), ac = accCur(accId);
    final t1 = <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'loan_pay', 'who': l['name'], 'accId': accId, 'amount': round2(lconv(l, v, cur, ac)), 'date': date, 'time': nowTime(), 'note': note, 'tags': <dynamic>[]};
    (data['txns'] as List).add(t1);
    String? feeId;
    if (fee > 0) {
      feeId = uid();
      (data['txns'] as List).add(<String, dynamic>{
        'id': feeId, 'type': 'expense', 'kind': 'bank_fee', 'who': l['name'], 'catId': _bankChargesCat, 'accId': accId, 'amount': round2(lconv(l, fee, cur, ac)),
        'date': date, 'time': nowTime(), 'note': 'Bank fee for loan payment', 'tags': <dynamic>[],
      });
    }
    (l['payments'] as List).add(<String, dynamic>{
      'id': uid(), 'amount': round2(lconv(l, v, cur, c)), 'paid': v, 'payCur': cur, 'rate': lconv(l, 1, cur, c), 'fee': fee, 'date': date, 'accId': accId, 'note': note,
      'txId': t1['id'], 'feeTxId': feeId,
    });
    commit();
  }

  void editLoanPayment(String lid, String pid, {required double v, required double fee, required String accId, required String date, required String note}) {
    final l = loan(lid);
    final p = l == null ? null : _pays(l).where((y) => y['id'] == pid).firstOrNull;
    if (l == null || p == null) return;
    final c = lcur(l), pc = '${p['payCur'] ?? c}', ac = accCur(accId);
    final rate = pc == c ? 1.0 : (toD(p['rate']) != 0 ? toD(p['rate']) : lconv(l, 1, pc, c));
    final oldFee = loanFeeTx(l, p);
    p.addAll({'paid': v, 'payCur': pc, 'rate': rate, 'amount': round2(pc == c ? v : v * rate), 'fee': fee, 'date': date, 'accId': accId, 'note': note});
    var tx = _tx(p['txId']);
    if (tx == null) {
      tx = <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'loan_pay', 'who': l['name'], 'time': nowTime(), 'tags': <dynamic>[]};
      (data['txns'] as List).add(tx);
      p['txId'] = tx['id'];
    }
    tx.addAll({'accId': accId, 'amount': round2(lconv(l, v, pc, ac)), 'date': date, 'note': note});
    if (fee > 0) {
      final ft = oldFee ?? <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'bank_fee', 'who': l['name'], 'catId': _bankChargesCat, 'time': nowTime(), 'note': 'Bank fee for loan payment', 'tags': <dynamic>[]};
      if (oldFee == null) (data['txns'] as List).add(ft);
      ft.addAll({'accId': accId, 'amount': round2(lconv(l, fee, pc, ac)), 'date': date});
      p['feeTxId'] = ft['id'];
    } else {
      if (oldFee != null) _dropTx({'${oldFee['id']}'});
      p['feeTxId'] = null;
    }
    commit();
  }

  void deleteLoanPayment(String lid, String pid) {
    final l = loan(lid);
    final p = l == null ? null : _pays(l).where((y) => y['id'] == pid).firstOrNull;
    if (l == null || p == null) return;
    final f = loanFeeTx(l, p);
    (l['payments'] as List).removeWhere((y) => y is Map && y['id'] == pid);
    _dropTx({if (p['txId'] != null) '${p['txId']}', if (f != null) '${f['id']}'});
    commit();
  }

  // ================================================================ lendings
  List<J> get lendings => _l5('lendings');
  J? lending(String id) => lendings.where((x) => x['id'] == id).firstOrNull;
  List<J> lendPayments(J x) => _pays(x);
  double lendPaid(J x) => _pays(x).fold(0.0, (a, p) => a + toD(p['amount']));
  double lendRemain(J x) => math.max(0.0, round2(toD(x['amount']) - lendPaid(x)));
  double lendRemainB(J x) => lconv(x, lendRemain(x), lcur(x), base);

  J? lendGiveTx(J x) =>
      txns.where((t) => t['kind'] == 'lend_give' && t['link'] is Map && (t['link'] as Map)['lend'] == x['id']).firstOrNull ??
      txns.where((t) => t['kind'] == 'lend_give' && !(t['link'] is Map && (t['link'] as Map)['lend'] != null) && t['who'] == x['name']).firstOrNull;

  /// Add or edit a lending. [rates] / [rateDir] are the agreed exchange rates for this lending only
  /// (same format as loans: units of CUR per 1 lending currency); without them the app rate is used.
  String saveLending({String? id, required String name, required String currency, required double amount, required String accId, required String due, required String note, String? taken, Map<String, double>? rates, Map<String, bool>? rateDir}) {
    final ac = accCur(accId);
    final lentNote = ac != currency ? 'Lent ${money(amount, currency)}' : '';
    final rs = <String, dynamic>{...?rates}, rd = <String, dynamic>{...?rateDir};
    if (id != null) {
      final x = lending(id)!;
      final gt = lendGiveTx(x);
      final oldA = toD(x['amount']), oldCur = lcur(x), oldAcc = gt?['accId'];
      x.addAll({'name': name, 'currency': currency, 'amount': amount, 'accId': accId, 'due': due, 'note': note});
      if (rates != null) {
        x['rates'] = rs;
        x['rateDir'] = rd;
      }
      if (taken != null && taken.isNotEmpty) {
        x['created'] = taken;
        if (gt != null) gt['date'] = taken;
      }
      if (gt != null) {
        final amt = ac == currency
            ? amount
            : rs[ac] != null
                ? round2(lconv(x, amount, currency, ac))
                : (oldCur == currency && oldAcc == accId && oldA > 0 ? round2(toD(gt['amount']) * amount / oldA) : round2(lconv(x, amount, currency, ac)));
        gt.addAll({'who': name, 'accId': accId, 'amount': amt, 'note': lentNote, 'link': <String, dynamic>{'lend': id}});
      } else {
        (data['txns'] as List).add(<String, dynamic>{
          'id': uid(), 'type': 'expense', 'kind': 'lend_give', 'who': name, 'accId': accId, 'amount': round2(lconv(x, amount, currency, ac)), 'date': x['created'] ?? today(),
          'time': nowTime(), 'note': lentNote, 'tags': <dynamic>[], 'link': <String, dynamic>{'lend': id},
        });
      }
      commit();
      return id;
    }
    final x = <String, dynamic>{'id': uid(), 'name': name, 'currency': currency, 'amount': amount, 'accId': accId, 'due': due, 'note': note, 'created': taken ?? today(), 'payments': <dynamic>[]};
    if (rs.isNotEmpty) {
      x['rates'] = rs;
      x['rateDir'] = rd;
    }
    _r5('lendings').add(x);
    (data['txns'] as List).add(<String, dynamic>{
      'id': uid(), 'type': 'expense', 'kind': 'lend_give', 'who': name, 'accId': accId, 'amount': round2(lconv(x, amount, currency, ac)), 'date': taken ?? today(), 'time': nowTime(),
      'note': lentNote, 'tags': <dynamic>[], 'link': <String, dynamic>{'lend': x['id']},
    });
    commit();
    return '${x['id']}';
  }

  void removeLending(String id) {
    final x = lending(id);
    if (x == null) return;
    final ids = <String>{};
    final gt = lendGiveTx(x);
    if (gt != null) ids.add('${gt['id']}');
    for (final p in _pays(x)) {
      if (p['txId'] != null) ids.add('${p['txId']}');
      if (p['expTxId'] != null) ids.add('${p['expTxId']}');
    }
    _dropTx(ids);
    (data['lendings'] as List).removeWhere((y) => y is Map && y['id'] == id);
    commit();
  }

  void receiveLending(String id, {required double v, required String cur, required String accId, required String date, required String note}) {
    final x = lending(id)!;
    _pays(x);
    final c = lcur(x);
    final t = <String, dynamic>{'id': uid(), 'type': 'income', 'kind': 'lend_receive', 'who': x['name'], 'accId': accId, 'amount': round2(lconv(x, v, cur, accCur(accId))), 'date': date, 'time': nowTime(), 'note': note, 'tags': <dynamic>[]};
    (data['txns'] as List).add(t);
    (x['payments'] as List).add(<String, dynamic>{'id': uid(), 'amount': round2(lconv(x, v, cur, c)), 'paid': v, 'payCur': cur, 'rate': lconv(x, 1, cur, c), 'accId': accId, 'date': date, 'note': note, 'txId': t['id']});
    commit();
  }

  /// Settle part of a lending against an expense the person paid for you (no cash moves):
  /// the lending goes down and the amount is booked as an expense in [catId].
  /// Two linked entries are made in the same account (lending settled + the expense), so balances don't change.
  void settleLendingAgainstExpense(String id, {required double v, required String cur, required String catId, required String date, required String note}) {
    final x = lending(id);
    if (x == null) return;
    _pays(x);
    final c = lcur(x);
    final accId = lendGiveTx(x)?['accId']?.toString() ?? x['accId']?.toString() ?? defaultAccId;
    if (accId == null) return;
    final ac = accCur(accId);
    final amt = round2(lconv(x, v, cur, ac));
    final t1 = <String, dynamic>{
      'id': uid(), 'type': 'income', 'kind': 'lend_offset', 'who': x['name'], 'accId': accId, 'amount': amt, 'date': date, 'time': nowTime(),
      'note': 'Settled against expense', 'tags': <dynamic>[], 'link': <String, dynamic>{'lend': id},
    };
    final t2 = <String, dynamic>{
      'id': uid(), 'type': 'expense', 'kind': 'normal', 'catId': catId, 'accId': accId, 'amount': amt, 'date': date, 'time': nowTime(),
      'note': note.trim().isEmpty ? 'Paid by ${x['name']} (lending settled)' : note.trim(), 'tags': <dynamic>[], 'link': <String, dynamic>{'lendExp': id},
    };
    (data['txns'] as List)
      ..add(t1)
      ..add(t2);
    (x['payments'] as List).add(<String, dynamic>{
      'id': uid(), 'amount': round2(lconv(x, v, cur, c)), 'paid': v, 'payCur': cur, 'rate': lconv(x, 1, cur, c), 'accId': accId, 'date': date, 'note': note,
      'txId': t1['id'], 'expTxId': t2['id'], 'method': 'expense', 'catId': catId,
    });
    commit();
  }

  void editLendPayment(String xid, String pid, {required double v, required String accId, required String date, required String note}) {
    final x = lending(xid);
    final p = x == null ? null : _pays(x).where((y) => y['id'] == pid).firstOrNull;
    if (x == null || p == null) return;
    final c = lcur(x), pc = '${p['payCur'] ?? c}', ac = accCur(accId);
    final rate = pc == c ? 1.0 : (toD(p['rate']) != 0 ? toD(p['rate']) : lconv(x, 1, pc, c));
    p.addAll({'paid': v, 'payCur': pc, 'rate': rate, 'amount': round2(pc == c ? v : v * rate), 'accId': accId, 'date': date, 'note': note});
    final et = p['expTxId'] == null ? null : _tx(p['expTxId']);
    if (et != null) et.addAll({'accId': accId, 'amount': round2(lconv(x, v, pc, ac)), 'date': date});
    var t = _tx(p['txId']);
    if (t == null) {
      t = <String, dynamic>{'id': uid(), 'type': 'income', 'kind': 'lend_receive', 'who': x['name'], 'time': nowTime(), 'tags': <dynamic>[]};
      (data['txns'] as List).add(t);
      p['txId'] = t['id'];
    }
    t.addAll({'accId': accId, 'amount': round2(lconv(x, v, pc, ac)), 'date': date, 'note': p['expTxId'] != null ? t['note'] : note});
    commit();
  }

  void deleteLendPayment(String xid, String pid) {
    final x = lending(xid);
    if (x == null) return;
    final p = _pays(x).where((y) => y['id'] == pid).firstOrNull;
    (x['payments'] as List).removeWhere((y) => y is Map && y['id'] == pid);
    if (p?['txId'] != null) _dropTx({'${p!['txId']}'});
    if (p?['expTxId'] != null) _dropTx({'${p!['expTxId']}'});
    commit();
  }

  /// Which loan / lending a linked transaction belongs to (for the transaction details sheet).
  ({String kind, String id})? loanLinkOfTx(J t) {
    final id = t['id'];
    for (final l in loans) {
      if (loanRecvTx(l)?['id'] == id) return (kind: 'loan', id: '${l['id']}');
      for (final p in _pays(l)) {
        if (p['txId'] == id || p['feeTxId'] == id) return (kind: 'loan', id: '${l['id']}');
      }
    }
    for (final x in lendings) {
      if (lendGiveTx(x)?['id'] == id) return (kind: 'lend', id: '${x['id']}');
      if (_pays(x).any((p) => p['txId'] == id || p['expTxId'] == id)) return (kind: 'lend', id: '${x['id']}');
    }
    return null;
  }

  // ================================================================ assets & fixed deposits
  List<J> get assetTypes {
    final l = _r5('assetTypes');
    if (l.isEmpty) {
      const defs = [
        ['Bank', '🏛️', 'asset'], ['Cash', '💵', 'asset'], ['Emergency Fund', '🛡️', 'asset'], ['Investment', '📈', 'asset'], ['Fixed Deposit', '🧾', 'asset'], ['Gold', '🪙', 'asset'],
        ['Property', '🏠', 'asset'], ['Vehicle', '🚗', 'asset'], ['Lending', '🤝', 'asset'], ['Bank Loan', '🏦', 'liability'], ['Personal Loan', '🤝', 'liability'],
        ['Credit Card', '💳', 'liability'], ['Installment Plan', '🧾', 'liability'],
      ];
      for (final d in defs) {
        l.add(<String, dynamic>{'id': uid(), 'name': d[0], 'icon': d[1], 'kind': d[2], 'group': _defGroup[d[0]], 'fd': d[0] == 'Fixed Deposit'});
      }
    }
    final out = l.whereType<Map>().map((e) => e as J).toList();
    for (final t in out) {
      t['group'] ??= _defGroup['${t['name']}'] ?? (t['kind'] == 'liability' ? 'Other Liability' : 'Fixed Assets');
      t['fd'] ??= t['name'] == 'Fixed Deposit';
    }
    return out;
  }

  J? atype(String? id) => assetTypes.where((t) => t['id'] == id).firstOrNull;
  List<J> get assets => _l5('assets');
  bool isFD(J a) => a['fd'] is Map;
  J fdOf(J a) => a['fd'] as J;
  double assetBase(J a) => isFD(a) ? conv(toD(a['value']), '${fdOf(a)['currency'] ?? base}', base) : toD(a['value']);
  String fdMaturity(J a) => addMonths('${fdOf(a)['start']}', toD(fdOf(a)['months']) > 0 ? toD(fdOf(a)['months']).toInt() : 12);
  double fdMonthly(J a) => toD(a['value']) * toD(fdOf(a)['rate']) / 100 / (fdOf(a)['basis'] == 'monthly' ? 1 : 12);
  String? fdNext(J a) {
    final f = fdOf(a);
    if (f['payout'] == 'maturity') return fdMaturity(a);
    final m = toD(f['months']) > 0 ? toD(f['months']).toInt() : 12;
    for (var k = 1; k <= m; k++) {
      final d = addMonths('${f['start']}', k);
      if (d.compareTo(today()) >= 0) return d;
    }
    return null;
  }

  /// Posts due FD interest into the linked account (each payment once — keys kept in fd.posted, shared with the web app).
  int runFDInterest({bool save = true}) {
    var n = 0;
    final ic0 = categories.where((c) => c['kind'] == 'income' && c['name'] == 'Interest').firstOrNull ?? categories.where((c) => c['kind'] == 'income').firstOrNull;
    for (final a in assets.where(isFD)) {
      final f = fdOf(a);
      final to = acc(f['accId']?.toString());
      if (to == null) continue;
      if (f['posted'] is! List) f['posted'] = <dynamic>[];
      final posted = f['posted'] as List;
      final m = toD(f['months']) > 0 ? toD(f['months']).toInt() : 12;
      void post(Object key, String d, double amt) {
        if (posted.any((x) => '$x' == '$key') || d.compareTo(today()) > 0) return;
        (data['txns'] as List).add(<String, dynamic>{
          'id': uid(), 'type': 'income', 'kind': 'normal', 'catId': ic0?['id'], 'accId': to['id'], 'amount': round2(conv(amt, '${f['currency'] ?? base}', '${to['currency']}')),
          'date': d, 'time': '09:00:00', 'note': 'FD interest — ${a['name']}', 'tags': <dynamic>['FD'], 'link': <String, dynamic>{'fd': a['id']},
        });
        posted.add(key);
        n++;
      }

      if (f['payout'] == 'maturity') {
        post('M', fdMaturity(a), fdMonthly(a) * m);
      } else {
        for (var k = 1; k <= m; k++) {
          post(k, addMonths('${f['start']}', k), fdMonthly(a));
        }
      }
    }
    if (n > 0 && save) commit();
    return n;
  }

  /// Returns how many FD interest payments were added.
  int saveAsset({String? id, required String name, required String typeId, required double value, required String note, J? fd}) {
    final r = <String, dynamic>{'name': name, 'typeId': typeId, 'value': value, 'note': note};
    if (fd != null) {
      final old = id == null ? null : assets.where((x) => x['id'] == id).firstOrNull?['fd'];
      final keep = old is Map && old['start'] == fd['start'] && old['payout'] == fd['payout'];
      r['fd'] = <String, dynamic>{...fd, 'posted': keep ? (old['posted'] ?? <dynamic>[]) : <dynamic>[]};
    }
    if (id != null) {
      final a = assets.where((x) => x['id'] == id).first;
      a.addAll(r);
      if (fd == null) a.remove('fd');
    } else {
      _r5('assets').add(<String, dynamic>{'id': uid(), ...r});
    }
    final n = runFDInterest(save: false);
    commit();
    return n;
  }

  void deleteAsset(String id) {
    (data['assets'] as List).removeWhere((a) => a is Map && a['id'] == id);
    commit();
  }

  // ================================================================ net worth (Financial Overview)
  NetWorth netWorthDetail() {
    final groups = <String, NwGroup>{};
    void add(String g, String name, double v) {
      final x = groups.putIfAbsent(g, () => NwGroup(g));
      x.items.add((name: name, v: v));
      x.v += v;
    }

    final accs = wallets.where((a) => a['include'] != false).map((a) => (name: '${a['name']}', v: accBalBase(a))).toList();
    final accSum = accs.where((x) => x.v > 0).fold(0.0, (a, x) => a + x.v);
    final assetSum = assets.fold(0.0, (a, x) => a + assetBase(x));
    final lent = lendings.fold(0.0, (a, x) => a + lendRemainB(x));
    final loanSum = loans.fold(0.0, (a, x) => a + loanRemainB(x));
    double cardOwed(J c, double bal) => math.max(0.0, conv(toD(c['limit']) - bal, '${c['currency'] ?? base}', base));
    final cardUsed = cards.fold(0.0, (a, c) => a + cardOwed(c, accBal(c)));
    final inst = installments.fold(0.0, (a, x) => a + instRemain(x));
    final neg = -accs.where((x) => x.v < 0).fold(0.0, (a, x) => a + x.v);
    final A = accSum + assetSum + lent, L = loanSum + cardUsed + inst + neg;

    for (final x in accs.where((x) => x.v > 0)) {
      add('Bank', x.name, x.v);
    }
    for (final x in lendings.where((x) => lendRemain(x) > 0)) {
      add('Lending', '${x['name']}', lendRemainB(x));
    }
    for (final a in assets) {
      final t = atype(a['typeId']?.toString());
      add(isFD(a) ? 'Fixed Deposits' : '${t?['group'] ?? 'Fixed Assets'}', '${a['name']}', assetBase(a));
    }
    final liab = <({String g, String name, double v})>[];
    for (final c in cards) {
      final v = cardOwed(c, accBal(c));
      if (v > 0) liab.add((g: 'Credit Card', name: '${c['name']}', v: v));
    }
    for (final l in loans) {
      final v = loanRemainB(l);
      if (v > 0) liab.add((g: 'Loan', name: '${l['name']}', v: v));
    }
    for (final x in installments) {
      final v = instRemain(x);
      if (v > 0) liab.add((g: 'Installment', name: '${x['title']}', v: v));
    }
    for (final x in accs.where((x) => x.v < 0)) {
      liab.add((g: 'Overdraft', name: x.name, v: -x.v));
    }
    final lg = <String, NwGroup>{};
    for (final x in liab) {
      final g = lg.putIfAbsent(x.g, () => NwGroup(x.g));
      g.items.add((name: x.name, v: x.v));
      g.v += x.v;
    }
    final all = groups.values.expand((g) => g.items).toList()..sort((a, b) => b.v.compareTo(a.v));
    final topL = [...liab]..sort((a, b) => b.v.compareTo(a.v));
    final ratio = A != 0 ? L / A : 0.0;
    final ins = <({String icon, String color, String text})>[
      (icon: 'bank', color: 'red', text: 'Your liabilities are ${(ratio * 100).toStringAsFixed(1)}% of your assets.'),
      (
        icon: 'bulb',
        color: '',
        text: ratio < .3
            ? 'Your financial health looks strong. Keep building assets and maintaining low debt.'
            : ratio < .6
                ? 'Your debt level is moderate. Paying down liabilities will strengthen your position.'
                : 'Your liabilities are high compared to your assets. Make reducing debt your priority.'
      ),
      if (all.isNotEmpty && A > 0) (icon: 'pie', color: 'orange', text: '${all.first.name} represents ${(all.first.v / A * 100).toStringAsFixed(1)}% of your total assets.'),
      if (topL.isNotEmpty) (icon: 'bulb', color: '', text: 'Your largest liability is ${topL.first.name}. Reducing it faster will improve your net worth.'),
    ];
    // change vs. end of last month
    final pe = addDays(monthStart(ym(today())), -1);
    double balUntil(J a) => txns.where((t) => t['accId'] == a['id'] && '${t['date']}'.compareTo(pe) <= 0).fold(0.0, (s, t) => s + (t['type'] == 'income' ? toD(t['amount']) : -toD(t['amount'])));
    final prevAcc = wallets.where((a) => a['include'] != false).fold(0.0, (s, a) => s + conv(balUntil(a), '${a['currency'] ?? base}', base));
    final prevA = A - accSum + math.max(0.0, prevAcc);
    final prevCards = cards.fold(0.0, (s, c) => s + cardOwed(c, balUntil(c)));
    final prevL = L - cardUsed + prevCards;
    double pct(double a, double b) => b != 0 ? (a - b) / b.abs() * 100 : 0;
    return NetWorth(A: A, L: L, groups: groups.values.toList(), lgroups: lg.values.toList(), ratio: ratio, ins: ins, chA: pct(A, prevA), chL: pct(L, prevL));
  }

  // ================================================================ Due Soon (home)
  List<DueItem> dueItems() {
    final t = today();
    final out = <DueItem>[];
    final hide = settings['dueHide'] is Map ? settings['dueHide'] as Map : const {};
    int dd(String d) => diffDays(t, d);
    void add(DueItem o) {
      if (o.days > 7 || hide[o.key] == true) return;
      out.add(o);
    }

    for (final l in loans) {
      final m = toD(l['months']).toInt();
      if (loanRemain(l) <= 0 || m <= 0) continue;
      final k = math.min(_pays(l).length, m) + 1;
      if (k > m) continue;
      final d = addMonths('${l['start']}', k - 1);
      add(DueItem(key: 'loan:${l['id']}:$d', id: '${l['id']}', scr: 'loan', name: '${l['name']}', amt: money(emiOf(l), lcur(l)), days: dd(d), kind: 'Loan'));
    }
    for (final x in lendings) {
      if ('${x['due'] ?? ''}'.isEmpty || lendRemain(x) <= 0) continue;
      add(DueItem(key: 'lend:${x['id']}:${x['due']}', id: '${x['id']}', scr: 'lending', name: '${x['name']}', amt: money(lendRemain(x), lcur(x)), days: dd('${x['due']}'), kind: 'To receive'));
    }
    for (final x in subs) {
      if (x['active'] == false || '${x['next'] ?? ''}'.isEmpty) continue;
      final lim = math.max(toD(x['remindDays'] ?? 3), 0);
      final n = dd('${x['next']}');
      if (n > lim) continue;
      add(DueItem(key: 'sub:${x['id']}:${x['next']}', id: '${x['id']}', scr: 'sub', name: '${x['name']}', amt: money(toD(x['amount']), '${x['currency'] ?? base}'), days: n, kind: 'Subscription'));
    }
    for (final r in recurring) {
      if ('${r['next'] ?? ''}'.isEmpty || r['paused'] == true) continue;
      final nm = '${r['title'] ?? ''}'.isNotEmpty ? '${r['title']}' : '${cat(r['catId']?.toString())?['name'] ?? 'Recurring'}';
      add(DueItem(key: 'rec:${r['id']}:${r['next']}', id: '${r['id']}', scr: 'rec', name: nm, amt: money(toD(r['amount']), accCur(r['accId']?.toString())), days: dd('${r['next']}'), kind: 'Recurring'));
    }
    for (final x in installments) {
      if (instRemain(x) <= 0) continue;
      final d = instNext(x);
      if (d == null) continue;
      add(DueItem(key: 'inst:${x['id']}:$d', id: '${x['id']}', scr: 'inst', name: '${x['title']}', amt: money(toD(x['amount']), base), days: dd(d), kind: 'Installment'));
    }
    out.sort((a, b) => a.days.compareTo(b.days));
    return out;
  }

  void hideDue(String key) {
    if (settings['dueHide'] is! Map) settings['dueHide'] = <String, dynamic>{};
    (settings['dueHide'] as Map)[key] = true;
    commit();
  }
}
