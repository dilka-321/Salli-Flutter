import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salli_flutter/core/round6.dart';
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
        {'id': 'sal', 'name': 'Salary', 'kind': 'income', 'icon': '💵', 'parent': null},
      ],
      'settings': {'base': 'LKR'},
    })) as Map<String, dynamic>;
    s.ensureShape();
  });

  test('goal: add money from an account, reach target, withdraw', () {
    s.saveGoal(name: 'Phone', target: 1000, deadline: '2027-01-01', icon: '📱', saved: 200);
    final id = '${s.goals.first['id']}';
    expect(s.goalSaved(s.goal(id)!), 200);
    final reached = s.goalMoney(id, 800, 1, 'lk');
    expect(reached, isTrue);
    expect(s.goal(id)!['completed'], isTrue);
    expect(s.txns.single['kind'], 'goal');
    s.goalMoney(id, 100, -1, null);
    expect(s.goalSaved(s.goal(id)!), 900);
  });

  test('todos, priorities and tags', () {
    s.saveTodo(title: 'Pay rent', tag: 'Finance', due: today());
    s.toggleTodo('${s.todos.first['id']}');
    expect(s.todos.first['done'], isTrue);
    s.savePriority({'title': 'Clear card', 'importance': 'High', 'urgency': 'Critical', 'category': 'Debt'});
    expect(s.prQuadrant(s.priorities.first).$1, 'Do first');
    expect(s.saveTag(null, 'Essential'), isNull);
    expect(s.saveTag(null, 'essential'), isNotNull);
    s.saveTx({'id': 'a', 'type': 'expense', 'kind': 'normal', 'catId': 'f', 'accId': 'lk', 'amount': 10, 'date': today(), 'time': '10:00:00', 'tags': ['Essential']});
    s.saveTag('${s.tags.first['id']}', 'Must');
    expect((s.txns.single['tags'] as List).single, 'Must');
    s.deleteTag('${s.tags.first['id']}');
    expect(s.txns.single['tags'] as List, isEmpty);
  });

  test('dashboard order keeps every widget; health score', () {
    s.saveDashboard(['recent', 'dues'], ['trend']);
    expect(s.widgetOrder.first, 'recent');
    expect(s.widgetOrder.length, kDefWidgets.length);
    expect(s.hiddenWidgets, ['trend']);
    final m = ym(today());
    s.saveTx({'id': 'i', 'type': 'income', 'kind': 'normal', 'catId': 'sal', 'accId': 'lk', 'amount': 1000, 'date': today(), 'time': '09:00:00'});
    s.saveTx({'id': 'e', 'type': 'expense', 'kind': 'normal', 'catId': 'f', 'accId': 'lk', 'amount': 500, 'date': today(), 'time': '10:00:00'});
    final h = s.healthScore(monthStart(m), monthEnd(m));
    expect(h.sr, .5);
    expect(h.parts.first.$2, 25);
    expect(h.score, greaterThan(50));
  });
}
