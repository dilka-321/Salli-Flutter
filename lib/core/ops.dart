import 'store.dart';
import 'util.dart';

/// Round 2 operations: transfers, credit cards, categories, deleting accounts.
/// Every rule here mirrors the Salli web app so both apps keep the same records.
extension Round2Ops on AppStore {
  List<dynamic> get _tx => data['txns'] as List;

  // ------------------------------------------------------------ transfers
  /// true when 1 [a] is worth at least 1 [b] (used to show "1 MVR = 17 LKR" style rates)
  bool fxStrong(String a, String b) => rates.rateOf(a, b) >= 1;

  /// Same as the web app's doTransfer. [rate] = to-currency per 1 from-currency typed by the user (0 = app rate).
  void doTransfer({
    required String from,
    required String to,
    required double amount,
    double fee = 0,
    required String date,
    String note = '',
    double rate = 0,
    String dir = 'fwd',
    String? group,
    String? time,
  }) {
    final fa = acc(from)!, ta = acc(to)!;
    final fc = '${fa['currency']}', tc = '${ta['currency']}';
    final toAmt = round2(conv(amount, fc, tc));
    final g = group ?? uid();
    final tm = time ?? nowTime();
    final o = <String, dynamic>{'id': uid(), 'type': 'expense', 'kind': 'transfer_out', 'accId': from, 'amount': round2(amount), 'date': date, 'time': tm, 'note': note, 'tags': <dynamic>[], 'group': g, 'peer': to};
    final i = <String, dynamic>{'id': uid(), 'type': 'income', 'kind': 'transfer_in', 'accId': to, 'amount': toAmt, 'date': date, 'time': tm, 'note': note, 'tags': <dynamic>[], 'group': g, 'peer': from};
    o['pair'] = i['id'];
    i['pair'] = o['id'];
    _tx..add(o)..add(i);
    if (fc != tc && rate > 0) {
      final real = round2(amount * rate), diff = round2(real - toAmt);
      o['fxRate'] = rate;
      o['fxDir'] = dir;
      o['appRate'] = rates.rateOf(fc, tc);
      final q = dir == 'rev' ? '1 $tc = ${(1 / rate).toStringAsFixed(4)} $fc' : '1 $fc = ${rate.toStringAsFixed(4)} $tc';
      if (diff.abs() >= 0.01) {
        _tx.add({
          'id': uid(),
          'type': diff > 0 ? 'income' : 'expense',
          'kind': diff > 0 ? 'fx_gain' : 'fx_loss',
          'accId': to,
          'amount': diff.abs(),
          'date': date,
          'time': tm,
          'note': 'Exchange ${diff > 0 ? 'gain' : 'loss'} on transfer from ${fa['name']} ($q)',
          'tags': <dynamic>[],
          'group': g,
        });
      }
    }
    if (fee > 0) {
      String? bankCat;
      for (final c in categories) {
        if (c['name'] == 'Bank Charges') bankCat = '${c['id']}';
      }
      _tx.add({'id': uid(), 'type': 'expense', 'kind': 'bank_fee', 'catId': bankCat, 'accId': from, 'amount': round2(fee), 'date': date, 'time': nowTime(), 'note': 'Transfer fee', 'tags': <dynamic>[], 'group': g});
    }
  }

  void saveTransfer({
    String? editGroup,
    String? editTime,
    required String from,
    required String to,
    required double amount,
    double fee = 0,
    required String date,
    String note = '',
    double rate = 0,
    String dir = 'fwd',
  }) {
    if (editGroup != null) _tx.removeWhere((t) => t is Map && t['group'] == editGroup);
    doTransfer(from: from, to: to, amount: amount, fee: fee, date: date, note: note, rate: rate, dir: dir, group: editGroup, time: editTime);
    commit();
  }

  void deleteTransfer(String group) {
    _tx.removeWhere((t) => t is Map && t['group'] == group);
    commit();
  }

  /// One entry per transfer (its "out" side), newest first.
  List<J> get transfers {
    final m = <String, J>{};
    for (final t in txns) {
      if (t['kind'] == 'transfer_out') m['${t['group']}'] = t;
    }
    final l = m.values.toList()..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    return l;
  }

  J? transferIn(J out) {
    for (final t in txns) {
      if (t['id'] == out['pair']) return t;
    }
    return null;
  }

  double transferFx(String group) {
    double v = 0;
    for (final t in txns) {
      if (t['group'] != group) continue;
      if (t['kind'] == 'fx_gain') v += toD(t['amount']);
      if (t['kind'] == 'fx_loss') v -= toD(t['amount']);
    }
    return v;
  }

  double transferFee(String group) {
    for (final t in txns) {
      if (t['group'] == group && t['kind'] == 'bank_fee') return toD(t['amount']);
    }
    return 0;
  }

  // ------------------------------------------------------------ credit cards
  bool hasRealTx(String accId) => txns.any((t) => t['accId'] == accId && t['kind'] != 'initial');

  void saveCard({
    String? id,
    required String name,
    required String currency,
    required double limit,
    required double available,
    required int billingDay,
    required int dueDay,
    required double interest,
    required double minPay,
    required bool includeCredit,
  }) {
    final fields = <String, dynamic>{
      'name': name,
      'currency': currency,
      'limit': limit,
      'billingDay': billingDay.clamp(1, 31),
      'dueDay': dueDay.clamp(1, 31),
      'interest': interest,
      'minPay': minPay <= 0 ? 5 : minPay,
      'includeCredit': includeCredit,
    };
    if (id != null) {
      final c = acc(id);
      if (c == null) return;
      c.addAll(fields);
      final d = round2(available - accBal(c));
      if (d != 0) {
        _tx.add({'id': uid(), 'type': d > 0 ? 'income' : 'expense', 'kind': 'correction', 'accId': id, 'amount': d.abs(), 'date': today(), 'time': nowTime(), 'note': 'Available amount updated', 'tags': <dynamic>[]});
      }
    } else {
      final nid = uid();
      (data['accounts'] as List).add({'id': nid, 'type': 'credit', 'include': true, 'isDefault': false, ...fields});
      if (available != 0) {
        _tx.add({'id': uid(), 'type': 'income', 'kind': 'initial', 'accId': nid, 'amount': round2(available), 'date': today(), 'time': nowTime(), 'note': '', 'tags': <dynamic>[]});
      }
    }
    commit();
  }

  double cardUsed(J c) {
    final u = toD(c['limit']) - accBal(c);
    return u > 0 ? u : 0;
  }

  /// next payment due date (same rule as the web app)
  String cardDue(J c) {
    final t = DateTime.now();
    final d0 = DateTime(t.year, t.month, t.day);
    final day = (c['dueDay'] is num) ? (c['dueDay'] as num).toInt() : int.tryParse('${c['dueDay']}') ?? 1;
    var d = DateTime(t.year, t.month, day);
    if (d.isBefore(d0)) d = DateTime(t.year, t.month + 1, day);
    return isoDate(d);
  }

  double cardMinimum(J c) => cardUsed(c) * (toD(c['minPay']) == 0 ? 5 : toD(c['minPay'])) / 100;

  /// Pay the card from a wallet (recorded as a transfer, like the web app).
  void payCard({required String cardId, required String fromId, required double amount}) {
    doTransfer(from: fromId, to: cardId, amount: amount, date: today(), note: 'Credit card payment');
    commit();
  }

  // ------------------------------------------------------------ accounts
  /// Deletes the account and all of its transactions (same as the web app).
  void deleteAccount(String id) {
    _tx.removeWhere((t) => t is Map && t['accId'] == id);
    (data['accounts'] as List).removeWhere((a) => a is Map && a['id'] == id);
    commit();
  }

  int txCount(String accId) => txns.where((t) => t['accId'] == accId).length;

  // ------------------------------------------------------------ categories
  /// returns an error message, or null when saved
  String? saveCategory({String? id, required String kind, required String name, required String icon, String? parent}) {
    final n = name.trim();
    if (n.isEmpty) return 'Enter a category name.';
    if (categories.any((c) => c['kind'] == kind && '${c['name']}'.toLowerCase() == n.toLowerCase() && c['id'] != id)) {
      return 'A category with this name already exists.';
    }
    if (id != null) {
      final c = cat(id);
      if (c == null) return 'Category not found.';
      c['name'] = n;
      c['icon'] = icon;
      c['parent'] = (parent == null || parent.isEmpty) ? null : parent;
    } else {
      (data['categories'] as List).add({'id': uid(), 'name': n, 'icon': icon, 'kind': kind, 'parent': (parent == null || parent.isEmpty) ? null : parent});
    }
    commit();
    return null;
  }

  /// Transactions keep their entry but show without a category; subcategories become main categories.
  void deleteCategory(String id) {
    for (final c in categories) {
      if (c['parent'] == id) c['parent'] = null;
    }
    (data['categories'] as List).removeWhere((c) => c is Map && c['id'] == id);
    commit();
  }

  int catUseCount(String id) => txns.where((t) => t['catId'] == id).length;
}

const kCategoryIcons = [
  '🖨️', '🥊', '⚓', '🛡️', '🍎', '🏧', '📠', '↩️', '🎾', '🎈', '🏛️', '💈', '🏏', '🔋', '☂️', '🚲', '📝', '💵', '🔭', '🏡', '📚', '🍾', '💐', '🎳', '📦', '🍞',
  '💼', '🧋', '🦋', '⛺', '🌵', '🎂', '🧮', '📅', '📷', '🔥', '🍬', '🧢', '🚙', '🚗', '🚘', '⛽', '🃏', '🎟️', '💲', '🐱', '🎉', '📊', '🏠', '⚡', '🚰', '🗑️',
  '🛒', '☎️', '📶', '📺', '🧹', '🚕', '🅿️', '📖', '🎨', '🩺', '💊', '🦷', '👕', '💇', '🏋️', '🍕', '🍔', '☕', '🎭', '✈️', '🎁', '🎓', '🛍️', '🧸', '🐾', '🤲',
  '🏦', '💰', '💻', '🏢', '📈', '🏘️', '🪙', '💳', '🏥', '⚽', '🎮', '🎵', '🍼', '👶', '🧾', '🔧', '🏍️', '🚌', '🚆', '🛵', '🧴', '💄', '🕌', '⛪', '🛕', '🌾',
  '🐄', '🐟', '🥦', '🍚', '🧂', '🍳', '🍰', '🍷', '🚬', '📱', '🖥️', '🔌', '💡', '🚿', '🛏️', '🪑', '🧺', '🪴', '🌐', '📮', '🎤', '🏖️', '🏨', '🎒', '✏️',
];
