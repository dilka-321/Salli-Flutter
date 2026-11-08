import 'dart:math' as math;

import 'loans.dart';
import 'planning.dart';
import 'plans.dart';
import 'store.dart';
import 'util.dart';

const kDefWidgets = ['sms', 'dues', 'balance', 'accounts', 'fds', 'recent', 'trend', 'budget', 'subs', 'inst', 'loan', 'expense', 'standing'];
const kWidgetNames = {
  'dues': 'Due Soon', 'fds': 'Fixed Deposits', 'sms': 'SMS Automation', 'balance': 'Balance Overview', 'accounts': 'My Accounts', 'recent': 'Recent Transactions',
  'trend': 'Spending Trend', 'budget': 'Budget Progress', 'subs': 'Upcoming Subscriptions', 'inst': 'Installment Overview', 'loan': 'Loan Overview',
  'expense': 'Expense Summary', 'standing': 'Standing Orders',
};
const kGoalIcons = ['🎯', '🛡️', '💻', '📱', '🚗', '🏍️', '🏠', '✈️', '🎓', '💍', '👶', '🏖️', '🎁', '🏥', '💰', '📈'];
const kTodoTags = ['Personal', 'Work', 'Finance', 'Family', 'Shopping'];
const kLevels = {'Low': 1, 'Medium': 2, 'High': 3, 'Critical': 4};
const kPrCategories = ['Debt', 'Savings', 'Bills', 'Investment', 'Purchase', 'Family', 'Health', 'Other'];
const kGroupIcon = {'Cash': '💵', 'Bank': '🏛️', 'Lending': '🤝', 'Fixed Assets': '🏠', 'Saving Goals': '🛡️', 'Investment': '📈', 'Credit Card': '💳', 'Loan': '🏦', 'Installment': '🧾'};

class HealthScore {
  HealthScore(this.score, this.grade, this.label, this.parts, this.sr, this.st, this.ps);
  final int score;
  final String grade, label;
  final List<(String, int, int, String)> parts;
  final double sr;
  final ({double inc, double exp, double cin, double cout}) st, ps;
}

/// Round 6: goals, to-do, priority board, tags, account groups, dashboard layout, analytics & report figures — same rules as the web app.
extension Round6Ops on AppStore {
  List<dynamic> _r6(String k) {
    if (data[k] is! List) data[k] = <dynamic>[];
    return data[k] as List;
  }

  List<J> _l6(String k) => _r6(k).whereType<Map>().map((e) => e as J).toList();

  // ================================================================ goals
  J? goal(String id) => goals.where((g) => g['id'] == id).firstOrNull;
  List<J> goalContribs(J g) {
    if (g['contributions'] is! List) g['contributions'] = <dynamic>[];
    return (g['contributions'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  /// whole months left until the goal's date (at least 1), or 0 when there is no date
  int goalMonthsLeft(J g) => '${g['deadline'] ?? ''}'.isEmpty ? 0 : math.max(1, (diffDays(today(), '${g['deadline']}') / 30).ceil());

  void saveGoal({String? id, required String name, required double target, required String deadline, required String icon, double saved = 0}) {
    if (id != null) {
      goal(id)?.addAll({'name': name, 'target': target, 'deadline': deadline, 'icon': icon});
    } else {
      _r6('goals').add(<String, dynamic>{
        'id': uid(), 'name': name, 'target': target, 'deadline': deadline, 'icon': icon,
        'contributions': <dynamic>[if (saved > 0) <String, dynamic>{'id': uid(), 'amount': saved, 'date': today(), 'accId': null}],
        'completed': saved >= target,
      });
    }
    commit();
  }

  /// Add (sign 1) or withdraw (sign -1) money in the main currency; with an account it also records the money moving. Returns true when the goal was just reached.
  bool goalMoney(String id, double v, int sign, String? accId) {
    final g = goal(id)!;
    goalContribs(g);
    final gtx = accId != null ? uid() : null;
    (g['contributions'] as List).add(<String, dynamic>{'id': uid(), 'amount': v * sign, 'date': today(), 'accId': accId, 'txId': gtx});
    if (accId != null) {
      (data['txns'] as List).add(<String, dynamic>{
        'id': gtx, 'type': sign > 0 ? 'expense' : 'income', 'kind': 'goal', 'who': g['name'], 'accId': accId, 'amount': round2(conv(v, base, accCur(accId))), 'date': today(),
        'time': nowTime(), 'note': '${sign > 0 ? 'Saved to ' : 'Withdrawn from '}${g['name']}', 'tags': <dynamic>[],
      });
    }
    var reached = false;
    if (goalSaved(g) >= toD(g['target']) && g['completed'] != true) {
      g['completed'] = true;
      reached = true;
    }
    commit();
    return reached;
  }

  void toggleGoal(String id) {
    final g = goal(id)!;
    g['completed'] = g['completed'] != true;
    commit();
  }

  void deleteGoal(String id) {
    (data['goals'] as List).removeWhere((g) => g is Map && g['id'] == id);
    commit();
  }

  // ================================================================ to-do
  List<J> get todos => _l6('todos');
  void saveTodo({String? id, required String title, required String tag, required String due}) {
    final r = <String, dynamic>{'title': title, 'tag': tag, 'due': due};
    if (id != null) {
      todos.where((x) => x['id'] == id).firstOrNull?.addAll(r);
    } else {
      _r6('todos').add(<String, dynamic>{'id': uid(), ...r, 'done': false});
    }
    commit();
  }

  void toggleTodo(String id) {
    final t = todos.where((x) => x['id'] == id).first;
    t['done'] = t['done'] != true;
    commit();
  }

  void deleteTodo(String id) {
    (data['todos'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  // ================================================================ priority board
  List<J> get priorities => _l6('priorities');
  int prScore(J p) => (kLevels['${p['importance']}'] ?? 2) * (kLevels['${p['urgency']}'] ?? 2);
  (String, String) prQuadrant(J p) {
    final i = kLevels['${p['importance']}'] ?? 2, u = kLevels['${p['urgency']}'] ?? 2;
    if (i >= 3 && u >= 3) return ('Do first', 'red');
    if (i >= 3) return ('Schedule', 'blue');
    if (u >= 3) return ('Delegate / quick', 'orange');
    return ('Later', '');
  }

  void savePriority(J e) {
    final r = <String, dynamic>{...e};
    if (e['id'] != null) {
      priorities.where((x) => x['id'] == e['id']).firstOrNull?.addAll(r);
    } else {
      _r6('priorities').add(<String, dynamic>{...r, 'id': uid(), 'done': false});
    }
    commit();
  }

  void togglePriority(String id) {
    final p = priorities.where((x) => x['id'] == id).first;
    p['done'] = p['done'] != true;
    commit();
  }

  void deletePriority(String id) {
    (data['priorities'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  // ================================================================ tags
  List<J> get tags => _l6('tags');

  /// returns an error message, or null when saved
  String? saveTag(String? id, String name) {
    final n = name.trim();
    if (n.isEmpty) return 'Enter a tag name.';
    if (tags.any((t) => '${t['name']}'.toLowerCase() == n.toLowerCase() && t['id'] != id)) return 'That tag already exists.';
    if (id != null) {
      final t = tags.where((x) => x['id'] == id).first;
      final old = '${t['name']}';
      t['name'] = n;
      for (final x in txns) {
        if (x['tags'] is List) x['tags'] = (x['tags'] as List).map((g) => g == old ? n : g).toList();
      }
    } else {
      _r6('tags').add(<String, dynamic>{'id': uid(), 'name': n});
    }
    commit();
    return null;
  }

  void deleteTag(String id) {
    final t = tags.where((x) => x['id'] == id).firstOrNull;
    if (t == null) return;
    (data['tags'] as List).removeWhere((x) => x is Map && x['id'] == id);
    for (final x in txns) {
      if (x['tags'] is List) x['tags'] = (x['tags'] as List).where((g) => g != t['name']).toList();
    }
    commit();
  }

  // ================================================================ account setup (asset / liability groups)
  void saveGroup({String? id, required String name, required String kind, required String group}) {
    final r = <String, dynamic>{'name': name, 'kind': kind, 'group': group};
    if (id != null) {
      atype(id)?.addAll(r);
    } else {
      assetTypes; // makes sure the defaults exist first
      _r6('assetTypes').add(<String, dynamic>{'id': uid(), 'icon': kGroupIcon[group] ?? '💼', ...r});
    }
    commit();
  }

  /// false when assets still use the group
  bool deleteGroup(String id) {
    if (assets.any((a) => a['typeId'] == id)) return false;
    (data['assetTypes'] as List).removeWhere((t) => t is Map && t['id'] == id);
    commit();
    return true;
  }

  // ================================================================ dashboard layout
  List<String> get widgetOrder {
    final o = settings['widgets'] is List ? (settings['widgets'] as List).map((e) => '$e').toList() : [...kDefWidgets];
    for (final w in kDefWidgets) {
      if (!o.contains(w)) o.add(w);
    }
    return o;
  }

  List<String> get hiddenWidgets => settings['hidden'] is List ? (settings['hidden'] as List).map((e) => '$e').toList() : <String>[];

  void saveDashboard(List<String> order, List<String> hidden) {
    settings['widgets'] = <dynamic>[...order];
    settings['hidden'] = <dynamic>[...hidden];
    commit();
  }

  // ================================================================ analytics / reports
  List<J> statList(String f, String t) => txns.where((x) {
        final d = '${x['date']}';
        if (d.compareTo(f) < 0 || d.compareTo(t) > 0) return false;
        final a = acc(x['accId']?.toString());
        return a?['include'] != false || a?['type'] == 'credit';
      }).toList();

  HealthScore healthScore(String f, String t) {
    final st = stats(f, t);
    final len = diffDays(f, t) + 1;
    final ps = stats(addDays(f, -len), addDays(f, -1));
    final sr = st.inc != 0 ? (st.inc - st.exp) / st.inc : (st.exp != 0 ? -1.0 : 0.0);
    final p1 = (sr / .2 * 25).round().clamp(0, 25).toInt();
    int p2;
    String n2;
    if (budgets.isEmpty) {
      p2 = 15;
      n2 = 'No budgets set';
    } else {
      final ok = budgets.where((b) => budgetSpent(b) <= toD(b['amount'])).length;
      p2 = (ok / budgets.length * 25).round();
      n2 = '$ok of ${budgets.length} budgets on track';
    }
    int p3;
    String n3;
    if (ps.exp == 0) {
      p3 = 12;
      n3 = 'No prior period data';
    } else {
      final ch = (st.exp - ps.exp) / ps.exp;
      p3 = ch <= 0 ? 20 : ch <= .1 ? 14 : 6;
      n3 = ch <= 0 ? 'Spending down ${(-ch * 100).round()}%' : 'Spending up ${(ch * 100).round()}%';
    }
    final ratio = st.exp != 0 ? st.inc / st.exp : (st.inc != 0 ? 9.0 : 1.0);
    final p4 = ratio >= 1.5 ? 20 : ratio >= 1.2 ? 16 : ratio >= 1 ? 12 : ratio >= .8 ? 6 : 2;
    final n4 = ratio >= 1.2 ? 'Healthy income cushion' : ratio >= .8 ? 'Income near expenses' : 'Expenses exceed income';
    final debtPay = statList(f, t).where((x) => x['kind'] == 'loan_pay' || x['kind'] == 'inst').fold(0.0, (a, x) => a + tBase(x));
    final dl = st.inc != 0 ? debtPay / st.inc : (debtPay != 0 ? 1.0 : 0.0);
    final p5 = dl == 0 ? 10 : dl < .2 ? 8 : dl < .4 ? 5 : 2;
    final n5 = dl == 0 ? 'No outstanding debt payments' : '${(dl * 100).round()}% of income to debt';
    final score = p1 + p2 + p3 + p4 + p5;
    final g = score >= 85 ? ('A', 'Excellent') : score >= 70 ? ('B', 'Good') : score >= 55 ? ('C', 'Average') : score >= 40 ? ('D', 'Fair') : ('F', 'Poor');
    return HealthScore(score, g.$1, g.$2, [
      ('Savings Rate', p1, 25, sr < 0 ? 'Negative savings' : '${(sr * 100).round()}% saved'),
      ('Budget Adherence', p2, 25, n2),
      ('Spending Trend', p3, 20, n3),
      ('Income-Expense Ratio', p4, 20, n4),
      ('Debt Load', p5, 10, n5),
    ], sr, st, ps);
  }

  List<String> recommendations(HealthScore h, String Function(num) B) {
    final out = <String>[];
    final st = h.st;
    if (h.sr < .2 && st.inc != 0) out.add('Save ${B(math.max(0, .2 * st.inc - (st.inc - st.exp)).round())} more per month to reach the 20% savings target (current rate: ${(h.sr * 100).toStringAsFixed(1)}%).');
    if (budgets.isEmpty) {
      out.add('Set budgets for your biggest spending categories to track adherence.');
    } else {
      for (final b in budgets.where((b) => budgetSpent(b) > toD(b['amount'])).take(2)) {
        out.add('"${b['name']}" is over budget by ${B(budgetSpent(b) - toD(b['amount']))}. Review these expenses.');
      }
    }
    if (h.ps.exp != 0 && st.exp > h.ps.exp * 1.1) out.add('Spending rose ${((st.exp / h.ps.exp - 1) * 100).round()}% versus the previous period.');
    final sb = subs.where((x) => x['active'] != false).fold(0.0, (a, x) => a + subMonthly(x));
    if (sb > 0) out.add('Subscriptions cost ${B(sb)} a month. Cancel any you rarely use.');
    if (out.isEmpty) out.add('Great work — keep your current habits and consider investing your surplus.');
    return out.take(4).toList();
  }

  void addReport(String f, String t) {
    final l = _r6('reports');
    l.add(<String, dynamic>{'id': uid(), 'from': f, 'to': t, 'at': DateTime.now().toIso8601String()});
    while (l.length > 30) {
      l.removeAt(0);
    }
    commit();
  }

  void deleteReport(String id) {
    (data['reports'] as List).removeWhere((r) => r is Map && r['id'] == id);
    commit();
  }

  /// monthly debt payments (EMIs of active loans with a tenure + active installments) in the main currency
  double monthlyDebtPayments() =>
      loans.where((l) => loanRemain(l) > 0 && hasTenure(l)).fold(0.0, (a, l) => a + emiB(l)) + installments.where((x) => instRemain(x) > 0).fold(0.0, (a, x) => a + toD(x['amount']));
}
