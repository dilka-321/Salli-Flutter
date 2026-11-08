import 'dart:convert';

import 'package:http/http.dart' as http;

import 'currency.dart';
import 'currency_table.dart';
import 'default_data.dart';
import 'loans.dart';
import 'ops.dart';
import 'planning.dart';
import 'plans.dart';
import 'round6.dart';
import 'store.dart';
import 'util.dart';

const kBackupFreq = {'daily': ('Daily', 1), 'weekly': ('Weekly', 7), 'monthly': ('Monthly', 30)};
const kFontSizes = [(0.9, 'Small'), (1.0, 'Default'), (1.1, 'Large'), (1.22, 'Extra large')];

/// Same PIN hash as the web app, so one PIN works in both apps.
String pinHash(String s) {
  var h = 5381;
  for (final c in 'salli:$s'.codeUnits) {
    h = (((h << 5) + h + c)).toSigned(32);
  }
  return 'h${(h & 0xFFFFFFFF).toRadixString(36)}';
}

class AppNotice {
  AppNotice(this.level, this.icon, this.title, this.sub, this.scr, this.id);
  final String level, icon, title, sub, scr, id;
}

/// Round 7: backup & restore, app lock, settings, notifications, SMS parser, exchange rates, admin — same rules as the web app.
extension Round7Ops on AppStore {
  J _setMap(String k, J def) {
    if (settings[k] is! Map) settings[k] = def;
    return settings[k] as J;
  }

  // ================================================================ backup
  J get autoBk => _setMap('autoBk', <String, dynamic>{'on': false, 'freq': 'weekly', 'gmail': false, 'last': null, 'lastMail': null});

  String backupJson() => jsonEncode({'app': 'salli', 'v': 2, 'at': DateTime.now().toIso8601String(), 'data': {...data, 'backupSnap': null}});

  String backupName() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return 'Salli_Backup_${d.year}-${p(d.month)}-${p(d.day)}_${p(d.hour)}${p(d.minute)}.json';
  }

  void markBackup({bool auto = false, bool mail = false}) {
    final now = DateTime.now().toIso8601String();
    settings['lastBackup'] = now;
    if (auto) autoBk['last'] = now;
    if (mail) autoBk['lastMail'] = now;
    commit();
  }

  bool backupDue(String? last, int days) => last == null || last.isEmpty || DateTime.now().difference(DateTime.tryParse(last) ?? DateTime(2000)).inMinutes >= days * 1440 - 60;

  /// Checks a backup file; returns (data, when) or throws a readable message.
  (J, String?) parseBackup(String text) {
    final o = jsonDecode(text);
    if (o is! Map) throw 'That file isn’t a Salli backup. Choose the .json backup file.';
    final d = o['data'] is Map ? o['data'] as Map : o;
    if (d['accounts'] is! List || d['txns'] is! List || d['settings'] is! Map) throw 'That file isn’t a Salli backup. Choose the .json backup file.';
    return (jsonDecode(jsonEncode(d)) as Map<String, dynamic>, o['at']?.toString());
  }

  /// Replaces everything with the backup (keeps the restored data's own settings, adds anything missing).
  void restoreBackup(J d) {
    d.remove('backupSnap');
    final cur = settings;
    data = d;
    final st = data['settings'] as J;
    for (final k in ['theme', 'accent', 'font']) {
      if (st[k] == null && cur[k] != null) st[k] = cur[k];
    }
    ensureShape();
    commit();
  }

  // ================================================================ app lock
  bool get hasPin => '${settings['pin'] ?? ''}'.isNotEmpty;
  bool checkPin(String pin) => pinHash(pin) == settings['pin'];
  void setPin(String? pin) {
    settings['pin'] = pin == null ? null : pinHash(pin);
    if (pin == null) settings['bio'] = null;
    commit();
  }

  void setBio(bool on) {
    settings['bio'] = on ? true : null;
    commit();
  }

  // ================================================================ appearance
  String get accentId {
    final a = settings['accent'];
    return a is Map ? '${a['id'] ?? 'emerald'}' : (a is String ? a : 'emerald');
  }

  void setAccent(String id) {
    final a = settings['accent'];
    settings['accent'] = <String, dynamic>{'id': id, 'hex': a is Map ? a['hex'] : null};
    commit();
  }

  double get fontScale {
    final f = settings['font'];
    final v = f is Map ? toD(f['scale']) : 0;
    return v > 0 ? v.toDouble() : 1.0;
  }

  void setFontScale(double v) {
    final f = _setMap('font', <String, dynamic>{'family': 'inter', 'scale': 1});
    f['scale'] = v;
    commit();
  }

  // ================================================================ currencies & rates
  List<String> get myCurrencies {
    if (settings['myCurrencies'] is! List) settings['myCurrencies'] = <dynamic>['USD', 'MVR', 'LKR', 'EUR'];
    return (settings['myCurrencies'] as List).map((e) => '$e').toList();
  }

  void toggleMyCurrency(String c) {
    final l = myCurrencies;
    if (l.contains(c)) {
      l.remove(c);
    } else {
      l.add(c);
    }
    settings['myCurrencies'] = <dynamic>[...l];
    commit();
  }

  void setBaseCurrency(String c) {
    settings['base'] = c;
    final l = myCurrencies;
    if (!l.contains(c)) settings['myCurrencies'] = <dynamic>[...l, c];
    commit();
  }

  List<J> get manualRates => ((data['rates'] as List?) ?? const []).whereType<Map>().map((e) => e as J).toList();

  void saveRate(String? id, String from, String to, double rate) {
    final l = data['rates'] as List;
    l.removeWhere((x) => x is Map && (x['id'] == id || (x['from'] == from && x['to'] == to) || (x['from'] == to && x['to'] == from)));
    l.add(<String, dynamic>{'id': id ?? uid(), 'from': from, 'to': to, 'rate': rate, 'date': today(), 'manual': true});
    commit();
  }

  void deleteRate(String id) {
    (data['rates'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  J? get liveInfo => data['live'] is Map ? data['live'] as J : null;

  /// Downloads today's reference rates (same source as the web app). Returns 'updated', 'fresh' or 'failed'.
  Future<String> refreshLiveRates({bool force = false}) async {
    final at = DateTime.tryParse('${liveInfo?['at'] ?? ''}');
    if (!force && at != null && DateTime.now().difference(at).inHours < 24) return 'fresh';
    try {
      final r = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return 'failed';
      final j = jsonDecode(r.body);
      if (j is! Map || j['rates'] is! Map || (j['rates'] as Map)['LKR'] == null) return 'failed';
      data['live'] = <String, dynamic>{
        'date': today(), 'at': DateTime.now().toIso8601String(), 'providerUpdatedAt': j['time_last_update_utc'], 'providerNextUpdateAt': j['time_next_update_utc'],
        'rates': Map<String, dynamic>.from(j['rates'] as Map), 'source': 'open.er-api.com',
      };
      commit();
      return 'updated';
    } catch (_) {
      return 'failed';
    }
  }

  List<Currency> get currencyOrder {
    final mine = myCurrencies.where((c) => kCurrencyMap[c] != null).toList();
    return [...mine.map((c) => kCurrencyMap[c]!), ...kCurrencies.where((c) => !mine.contains(c.code))];
  }

  // ================================================================ notifications
  J get notifSettings => _setMap('notif', <String, dynamic>{'bills': true, 'budget': true, 'subs': true, 'inst': true, 'daily': false});

  List<AppNotice> notifications() {
    final t = today(), out = <AppNotice>[], n = notifSettings;
    bool soon(String? d, [int k = 7]) => d != null && d.isNotEmpty && diffDays(t, d) <= k;
    String when(String d) {
      final k = diffDays(t, d);
      return k < 0 ? '${-k} days overdue' : k == 0 ? 'today' : k == 1 ? 'tomorrow' : 'in $k days';
    }

    String lvl(String d) => d.compareTo(t) < 0 ? 'r' : 'o';
    if (n['subs'] != false) {
      for (final x in subs.where((x) => x['active'] != false)) {
        final d = '${x['next'] ?? ''}';
        if (soon(d, x['remind'] == true ? (int.tryParse('${x['remindDays']}') ?? 3) : 7)) out.add(AppNotice(lvl(d), 'sub', '${x['name']} renews ${when(d)}', money(toD(x['amount']), '${x['currency'] ?? base}'), 'sub', '${x['id']}'));
      }
    }
    if (n['budget'] != false) {
      for (final b in budgets) {
        final a = toD(b['amount']);
        final p = a > 0 ? budgetSpent(b) / a : 0.0;
        if (p >= .8) out.add(AppNotice(p >= 1 ? 'r' : 'o', 'budget', '${b['name']} budget ${p >= 1 ? 'exceeded' : 'at ${(p * 100).round()}%'}', '${money(budgetSpent(b), base)} of ${money(a, base)}', 'budget', '${b['id']}'));
      }
    }
    if (n['inst'] != false) {
      for (final x in installments) {
        final d = instNext(x);
        final rd = int.tryParse('${x['remindDays'] ?? 1}') ?? 1;
        if (d != null && soon(d, rd > 7 ? rd : 7)) out.add(AppNotice(lvl(d), 'inst', '${x['title']} installment due ${when(d)}', money(toD(x['amount']), base), 'inst', '${x['id']}'));
      }
    }
    if (n['bills'] != false) {
      for (final l in loans) {
        if (loanRemain(l) > 0 && hasTenure(l)) {
          final d = addMonths('${l['start']}', loanPayments(l).length);
          if (soon(d)) out.add(AppNotice(lvl(d), 'bank', '${l['name']} instalment due ${when(d)}', money(emiOf(l), lcur(l)), 'loan', '${l['id']}'));
        }
      }
      for (final c in cards) {
        final used = toD(c['limit']) - accBal(c);
        final d = cardDue(c);
        if (used > 0 && soon(d)) out.add(AppNotice('o', 'card', '${c['name']} payment due ${when(d)}', '${money(used, '${c['currency']}')} used', 'card', '${c['id']}'));
      }
      for (final x in lendings) {
        final d = '${x['due'] ?? ''}';
        if (lendRemain(x) > 0 && soon(d)) out.add(AppNotice(lvl(d), 'hand', '${x['name']} owes you ${money(lendRemain(x), lcur(x))}', 'Due ${when(d)}', 'lending', '${x['id']}'));
      }
      for (final x in todos) {
        final d = '${x['due'] ?? ''}';
        if (x['done'] != true && soon(d, 2)) out.add(AppNotice(lvl(d), 'todo', '${x['title']}', 'To-do · ${when(d)}', 'todos', ''));
      }
      for (final r in recurring) {
        final d = '${r['next'] ?? ''}';
        if (soon(d, 3)) out.add(AppNotice(lvl(d), 'repeat', '${'${r['title'] ?? ''}'.isNotEmpty ? r['title'] : cat(r['catId']?.toString())?['name'] ?? 'Recurring'} payment due ${when(d)}', money(toD(r['amount']), accCur(r['accId']?.toString())), 'rec', '${r['id']}'));
      }
    }
    if (smsDrafts.isNotEmpty) out.insert(0, AppNotice('g', 'sms', '${smsDrafts.length} SMS draft${smsDrafts.length > 1 ? 's' : ''} to review', 'Tap to review and save', 'sms', ''));
    return out;
  }

  // ================================================================ SMS parser
  List<J> get smsDrafts {
    if (data['smsDrafts'] is! List) data['smsDrafts'] = <dynamic>[];
    return (data['smsDrafts'] as List).whereType<Map>().map((e) => e as J).toList();
  }

  static final _bank = RegExp(r"\b(BOC|COMBANK|COM ?BANK|HNB|SAMPATH|NDB|SEYLAN|NTB|NATIONS ?TRUST|DFCC|PEOPLES|PEOPLE'?S BANK|PAN ASIA|UNION ?BANK|AMANA|CARGILLS ?BANK|NSB|HSBC|SCB|CITI|BML|MIB|SBI|HDFC|ICICI|AXIS|HBL|MCB|UBL|MEEZAN)\b", caseSensitive: false);
  static final _merch = <(RegExp, String)>[
    (RegExp(r'keells|cargills|food ?city|laugfs|arpico|spar|glomark|super', caseSensitive: false), 'Groceries'),
    (RegExp(r'uber|pickme|taxi|bus|train', caseSensitive: false), 'Transport'),
    (RegExp(r'fuel|petrol|ceypetco|ioc|lanka ioc|shed', caseSensitive: false), 'Fuel'),
    (RegExp(r'dialog|mobitel|hutch|airtel|slt', caseSensitive: false), 'Phone'),
    (RegExp(r'ceb|leco|electric', caseSensitive: false), 'Electricity'),
    (RegExp(r'water|nwsdb', caseSensitive: false), 'Water'),
    (RegExp(r'kfc|pizza|mcdonald|burger|cafe|coffee|restaurant|hotel', caseSensitive: false), 'Dining'),
    (RegExp(r'daraz|odel|amazon|fashion|store|mall|shop', caseSensitive: false), 'Shopping'),
    (RegExp(r'pharm|hospital|clinic|osu|medical|lab|healthguard', caseSensitive: false), 'Meds'),
    (RegExp(r'netflix|spotify|youtube|cinema|scope|ticket', caseSensitive: false), 'Entertainment'),
    (RegExp(r'salary|payroll', caseSensitive: false), 'Salary'),
    (RegExp(r'interest', caseSensitive: false), 'Interest'),
  ];

  /// Same rules as the web app: returns a draft, {'skip': reason}, or null for empty text.
  J? parseSms(String raw) {
    final txt = raw.trim();
    if (txt.isEmpty) return null;
    RegExp re(String p) => RegExp(p, caseSensitive: false);
    if (re(r'\b(otp|one[- ]?time|verification code|passcode|pin is|do not share)\b').hasMatch(txt)) return {'skip': 'OTP'};
    final am = re(r'(?:LKR|Rs\.?|INR|PKR|MVR|USD|BDT|AED)\s*([\d,]+(?:\.\d{1,2})?)').firstMatch(txt) ?? RegExp(r'\b(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2})\b').firstMatch(txt);
    final isInc = re(r'\b(credited|credit(?:ed)? to|deposit(ed)?|received|salary|refund(ed)?|cr\b|incoming)').hasMatch(txt);
    final isExp = re(r'\b(debited|debit|purchase|spent|withdraw(n|al)?|paid|payment|txn|transaction at|pos\b|dr\b|charged)').hasMatch(txt);
    if (re(r'\b(offer|promo|win|discount|% ?off|click|reward points|hurry|limited time|sale)\b').hasMatch(txt) && !(isInc || isExp)) return {'skip': 'Promotion'};
    if (am == null || !(isInc || isExp)) return {'skip': 'Not a bank transaction'};
    final curm = re(r'\b(LKR|INR|PKR|MVR|USD|BDT|AED)\b').firstMatch(txt);
    final amount = double.tryParse(am.group(1)!.replaceAll(',', '')) ?? 0;
    final type = isInc && !re(r'\bdebited\b').hasMatch(txt) ? 'income' : 'expense';
    var merchant = '';
    final mm = re(r"\b(?:at|to|from|@)\s+([A-Za-z][A-Za-z0-9 &.'\-]{1,32}?)(?=\s+(?:on|for|ref|avl|avail|bal|via|\d)|[.,;]|$)").firstMatch(txt);
    if (mm != null) {
      merchant = mm.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase().replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());
    }
    var catName = type == 'income' ? 'Other Income' : 'Other';
    bool pick(String src) {
      for (final (r, n) in _merch) {
        if (r.hasMatch(src) && categories.any((x) => x['name'] == n && x['kind'] == type)) {
          catName = n;
          return true;
        }
      }
      return false;
    }

    if (!(merchant.isNotEmpty && pick(merchant))) pick(txt);
    final c = categories.where((x) => x['name'] == catName && x['kind'] == type).firstOrNull ?? categories.where((x) => x['kind'] == type).firstOrNull;
    var date = today();
    final dm = RegExp(r'\b(\d{1,2})[\/\-.](\d{1,2})(?:[\/\-.](\d{2,4}))?\b').firstMatch(txt);
    if (dm != null) {
      final mo = int.parse(dm.group(2)!), dy = int.parse(dm.group(1)!);
      if (mo >= 1 && mo <= 12 && dy <= 31) {
        final y3 = dm.group(3);
        final y = y3 != null ? (y3.length == 2 ? '20$y3' : y3) : today().substring(0, 4);
        date = '$y-${mo.toString().padLeft(2, '0')}-${dy.toString().padLeft(2, '0')}';
        if (date.compareTo(today()) > 0) date = today();
      }
    }
    final bank = _bank.firstMatch(txt)?.group(0) ?? '';
    final red = txt.replaceAll(RegExp(r'\b[X*x•]{2,}\s?\d{2,6}\b'), '••••').replaceAll(RegExp(r'\b\d{8,}\b'), '••••').replaceAll(re(r'(?:Avl|Avail(?:able)?)\.?\s*Bal[^.]*\.?'), '').trim();
    final key = bank.toUpperCase().replaceAll(' ', '');
    final cur = curm != null ? curm.group(1)!.toUpperCase() : base;
    final a = (bank.isNotEmpty ? accounts.where((x) => '${x['name']}'.toUpperCase().contains(key.substring(0, key.length < 3 ? key.length : 3))).firstOrNull : null) ??
        accounts.where((x) => x['currency'] == cur && x['type'] != 'credit').firstOrNull ??
        accounts.firstOrNull;
    return {'id': uid(), 'amount': amount, 'type': type, 'merchant': merchant, 'catId': c?['id'], 'accId': a?['id'], 'date': date, 'raw': red, 'bank': bank};
  }

  /// Parses pasted messages (blank line between them). Returns (drafts added, skipped reasons).
  (int, List<String>) addSmsDrafts(String text) {
    var ok = 0;
    final sk = <String>[];
    smsDrafts;
    for (final part in text.split(RegExp(r'\n\s*\n'))) {
      final r = parseSms(part);
      if (r == null) continue;
      if (r['skip'] != null) {
        sk.add('${r['skip']}');
      } else {
        (data['smsDrafts'] as List).add(r);
        ok++;
      }
    }
    commit();
    return (ok, sk);
  }

  void removeSmsDraft(String id) {
    (data['smsDrafts'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  int saveAllSmsDrafts() {
    final l = smsDrafts;
    for (final d in l) {
      (data['txns'] as List).add(<String, dynamic>{'id': uid(), 'type': d['type'], 'kind': 'normal', 'catId': d['catId'], 'accId': d['accId'], 'amount': d['amount'], 'date': d['date'], 'time': nowTime(), 'note': d['merchant'], 'tags': <dynamic>['SMS'], 'receipt': null});
    }
    data['smsDrafts'] = <dynamic>[];
    commit();
    return l.length;
  }

  // ================================================================ admin
  bool get isAdmin => profile?['role'] == 'admin';

  Future<List<J>> adminProfiles() async {
    final rows = await sb.from('profiles').select('user_id,email,status,role,created_at,full_name,phone,country,profile_completed').order('created_at', ascending: false);
    return (rows as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((x) => x['user_id'] != user?.id).toList();
  }

  Future<void> adminSetStatus(String userId, String status) async {
    await sb.from('profiles').update({'status': status}).eq('user_id', userId);
  }

  // ================================================================ erase
  void eraseAll() {
    final name = '${settings['name'] ?? ''}';
    final keep = {for (final k in ['theme', 'accent', 'font', 'base', 'name', 'email', 'phone', 'country']) k: settings[k]};
    data = newUserData(name);
    (data['settings'] as J).addAll({for (final e in keep.entries) if (e.value != null) e.key: e.value});
    ensureShape();
    commit();
  }
}
