import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'currency.dart';
import 'default_data.dart';
import 'util.dart';

enum Phase { loading, signedOut, pending, rejected, needsProfile, conflict, ready, error }

typedef J = Map<String, dynamic>;

/// The whole app state.
///
/// IMPORTANT: the data is kept exactly as the Salli web app stores it (one JSON document per user in
/// the `user_data` table). This app only changes the parts it knows about and always uploads the
/// complete document, so nothing the web app saved (loans, budgets, plans, …) is ever lost.
class AppStore extends ChangeNotifier with WidgetsBindingObserver {
  AppStore(this.prefs);

  final SharedPreferences prefs;
  SupabaseClient get sb => Supabase.instance.client;

  Phase phase = Phase.loading;
  String? message; // shown on the auth screens
  User? user;
  J? profile;
  J data = {};
  J? conflictRemote;

  bool dirty = false;
  String? lastRemoteAt;
  bool syncing = false;
  String syncStatus = '';
  Timer? _syncTimer;
  Timer? _retryTimer;

  // ---------------------------------------------------------------- start-up
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    sb.auth.onAuthStateChange.listen((e) {
      if (e.event == AuthChangeEvent.signedOut) {
        user = null;
        phase = Phase.signedOut;
        notifyListeners();
      }
    });
    _retryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (dirty) syncNow();
    });
    final session = sb.auth.currentSession;
    if (session == null) {
      phase = Phase.signedOut;
      notifyListeners();
      return;
    }
    user = session.user;
    await _afterSignIn();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && phase == Phase.ready) {
      if (dirty) {
        syncNow();
      } else {
        pullIfNewer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  String get _dataKey => 'salli.flutter.user.${user?.id}';
  String get _metaKey => '$_dataKey.meta';
  String get _profileKey => 'salli.flutter.profile.${user?.id}';

  Future<void> _afterSignIn() async {
    phase = Phase.loading;
    notifyListeners();
    J? prof;
    try {
      for (var i = 0; i < 4 && prof == null; i++) {
        final r = await sb
            .from('profiles')
            .select('user_id,email,role,status,created_at,full_name,phone,country,profile_completed')
            .eq('user_id', user!.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (r != null) {
          prof = Map<String, dynamic>.from(r);
        } else {
          await Future.delayed(const Duration(milliseconds: 450));
        }
      }
      if (prof != null) await prefs.setString(_profileKey, jsonEncode(prof));
    } catch (_) {
      // offline: use the profile saved on this phone
      final cached = prefs.getString(_profileKey);
      if (cached != null) prof = Map<String, dynamic>.from(jsonDecode(cached));
    }
    if (prof == null) {
      phase = Phase.signedOut;
      message = 'Your profile is being created. Please sign in again in a moment.';
      notifyListeners();
      return;
    }
    profile = prof;
    if (prof['status'] != 'approved') {
      phase = prof['status'] == 'rejected' ? Phase.rejected : Phase.pending;
      notifyListeners();
      return;
    }
    if (prof['role'] == 'user' && prof['profile_completed'] != true) {
      phase = Phase.needsProfile;
      notifyListeners();
      return;
    }
    await _openWorkspace();
  }

  Future<void> _openWorkspace() async {
    J? local;
    J meta = {};
    try {
      final raw = prefs.getString(_dataKey);
      if (raw != null) local = Map<String, dynamic>.from(jsonDecode(raw));
      final m = prefs.getString(_metaKey);
      if (m != null) meta = Map<String, dynamic>.from(jsonDecode(m));
    } catch (_) {}
    J? remote;
    bool offline = false;
    try {
      final r = await sb
          .from('user_data')
          .select('data,updated_at')
          .eq('user_id', user!.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      if (r != null) remote = Map<String, dynamic>.from(r);
    } catch (_) {
      offline = true;
    }
    final baseline = meta['lastSyncedRemoteAt'] as String?;
    final localDirty = meta['dirty'] == true;
    if (local != null && remote != null) {
      if (localDirty && baseline != null && _newer(remote['updated_at'], baseline)) {
        data = local;
        conflictRemote = remote;
        phase = Phase.conflict;
        notifyListeners();
        return;
      }
      if (localDirty) {
        data = local; // unsynced changes on this phone always win over an unchanged cloud copy
        dirty = true;
        lastRemoteAt = remote['updated_at'];
      } else {
        data = _asMap(remote['data']);
        dirty = false;
        lastRemoteAt = remote['updated_at'];
      }
    } else if (remote != null) {
      data = _asMap(remote['data']);
      lastRemoteAt = remote['updated_at'];
      dirty = false;
    } else if (local != null) {
      data = local;
      dirty = localDirty || !offline;
      lastRemoteAt = baseline;
    } else if (offline) {
      phase = Phase.error;
      message = 'No internet connection. Connect once to download your data.';
      notifyListeners();
      return;
    } else {
      data = newUserData(profile?['full_name'] ?? '');
      dirty = true;
    }
    ensureShape();
    await _writeLocal();
    phase = Phase.ready;
    syncStatus = offline ? 'Offline · saved on this phone' : (dirty ? 'Sync pending' : 'Synced');
    notifyListeners();
    if (dirty && !offline) syncNow();
  }

  J _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : newUserData('');

  bool _newer(dynamic a, String b) {
    final da = DateTime.tryParse('$a');
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.isAfter(db);
  }

  /// Fill in lists/settings this app reads, without touching anything else.
  void ensureShape() {
    for (final k in ['accounts', 'txns', 'categories', 'rates', 'loans', 'lendings', 'subs', 'recurring', 'installments', 'goals', 'budgets']) {
      if (data[k] is! List) data[k] = [];
    }
    if (data['settings'] is! Map) data['settings'] = <String, dynamic>{};
    final s = settings;
    s['base'] ??= 'LKR';
    s['theme'] ??= 'system';
  }

  // ---------------------------------------------------------------- conflict
  Future<void> resolveConflict({required bool keepCloud}) async {
    final r = conflictRemote;
    conflictRemote = null;
    if (r != null && keepCloud) {
      data = _asMap(r['data']);
      dirty = false;
      lastRemoteAt = r['updated_at'];
    } else if (r != null) {
      dirty = true;
      lastRemoteAt = r['updated_at'];
    }
    ensureShape();
    await _writeLocal();
    phase = Phase.ready;
    notifyListeners();
    if (dirty) syncNow();
  }

  // ---------------------------------------------------------------- saving + sync
  Future<void> _writeLocal() async {
    await prefs.setString(_dataKey, jsonEncode(data));
    await prefs.setString(_metaKey, jsonEncode({'dirty': dirty, 'lastSyncedRemoteAt': lastRemoteAt, 'savedAt': DateTime.now().toUtc().toIso8601String()}));
  }

  /// Call after every change.
  Future<void> commit() async {
    dirty = true;
    syncStatus = 'Saving…';
    notifyListeners();
    await _writeLocal();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 1200), syncNow);
  }

  Future<void> syncNow() async {
    if (syncing || !dirty || user == null || phase != Phase.ready) return;
    syncing = true;
    try {
      final remote = await sb.from('user_data').select('updated_at').eq('user_id', user!.id).maybeSingle().timeout(const Duration(seconds: 12));
      if (remote != null && lastRemoteAt != null && _newer(remote['updated_at'], lastRemoteAt!)) {
        final full = await sb.from('user_data').select('data,updated_at').eq('user_id', user!.id).maybeSingle();
        syncing = false;
        if (full != null) {
          conflictRemote = Map<String, dynamic>.from(full);
          phase = Phase.conflict;
          notifyListeners();
        }
        return;
      }
      final res = await sb
          .from('user_data')
          .upsert({'user_id': user!.id, 'data': data, 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'user_id')
          .select('updated_at')
          .single()
          .timeout(const Duration(seconds: 15));
      lastRemoteAt = res['updated_at'] as String?;
      dirty = false;
      syncStatus = 'Synced';
      await _writeLocal();
    } catch (e) {
      syncStatus = 'Saved on this phone · sync pending';
      debugPrint('Salli sync deferred: $e');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Bring in changes made in the web app since the last sync (only when this phone has none pending).
  Future<void> pullIfNewer() async {
    if (dirty || user == null) return;
    try {
      final r = await sb.from('user_data').select('data,updated_at').eq('user_id', user!.id).maybeSingle().timeout(const Duration(seconds: 12));
      if (r != null && (lastRemoteAt == null || _newer(r['updated_at'], lastRemoteAt!))) {
        data = _asMap(r['data']);
        lastRemoteAt = r['updated_at'];
        ensureShape();
        await _writeLocal();
        syncStatus = 'Synced';
        notifyListeners();
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------- auth actions
  Future<String?> signIn(String email, String password) async {
    try {
      final r = await sb.auth.signInWithPassword(email: email.trim(), password: password);
      user = r.user;
      message = null;
      await _afterSignIn();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not sign in. Check your internet connection.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final r = await sb.auth.signUp(email: email.trim(), password: password, emailRedirectTo: AppConfigUrls.redirect);
      if (r.session == null) return 'OK_CONFIRM';
      user = r.user;
      await _afterSignIn();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not create the account. Check your internet connection.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await sb.auth.resetPasswordForEmail(email.trim(), redirectTo: AppConfigUrls.redirect);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send the email. Check your internet connection.';
    }
  }

  Future<String?> saveProfileDetails(String name, String phone, String country) async {
    try {
      await sb.rpc('save_my_profile_details', params: {
        'p_full_name': name.trim(),
        'p_phone': phone.trim().isEmpty ? null : phone.trim(),
        'p_country': country.trim().isEmpty ? null : country.trim(),
      });
      profile = {...?profile, 'full_name': name.trim(), 'profile_completed': true};
      await prefs.setString(_profileKey, jsonEncode(profile));
      await _openWorkspace();
      return null;
    } catch (e) {
      return 'Could not save your details: $e';
    }
  }

  Future<void> recheckApproval() async {
    await _afterSignIn();
  }

  Future<void> signOut() async {
    if (dirty) await syncNow();
    try {
      await sb.auth.signOut();
    } catch (_) {}
    user = null;
    data = {};
    phase = Phase.signedOut;
    notifyListeners();
  }

  // ================================================================= finance helpers
  J get settings => data['settings'] as J;
  String get base => (settings['base'] ?? 'LKR').toString();
  List<J> _list(String k) => ((data[k] as List?) ?? []).whereType<Map>().map((e) => e as J).toList();
  List<J> get accounts => _list('accounts');
  List<J> get txns => _list('txns');
  List<J> get categories => _list('categories');
  List<J> get loans => _list('loans');

  Rates get rates {
    final live = data['live'];
    final lr = live is Map ? live['rates'] : null;
    return Rates(_list('rates'), lr is Map ? Map<String, dynamic>.from(lr) : null);
  }

  double conv(num v, String from, String to) => rates.conv(v, from, to);

  J? acc(String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a['id'] == id) return a;
    }
    return null;
  }

  String accCur(String? id) => (acc(id)?['currency'] ?? base).toString();
  String accName(String? id) => (acc(id)?['name'] ?? 'Deleted account').toString();
  bool isCard(J a) => a['type'] == 'credit';
  List<J> get wallets => accounts.where((a) => !isCard(a)).toList();
  List<J> get cards => accounts.where(isCard).toList();

  String? get defaultAccId {
    for (final a in wallets) {
      if (a['isDefault'] == true) return a['id'];
    }
    return wallets.isNotEmpty ? wallets.first['id'] : (accounts.isNotEmpty ? accounts.first['id'] : null);
  }

  J? cat(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  double accBal(J a) {
    double b = 0;
    final id = a['id'];
    for (final t in txns) {
      if (t['accId'] == id) b += t['type'] == 'income' ? toD(t['amount']) : -toD(t['amount']);
    }
    return round2(b);
  }

  double accBalBase(J a) => conv(accBal(a), (a['currency'] ?? base).toString(), base);
  double get totalBalance => wallets.where((a) => a['include'] != false).fold(0.0, (s, a) => s + accBalBase(a));

  static const _statInc = ['normal', 'recurring', 'fx_gain'];
  static const _statExp = ['normal', 'recurring', 'sub', 'inst', 'bank_fee', 'fx_loss'];
  bool isInc(J t) => t['type'] == 'income' && _statInc.contains(t['kind'] ?? 'normal');
  bool isExp(J t) => t['type'] == 'expense' && _statExp.contains(t['kind'] ?? 'normal');
  bool isCashIn(J t) => t['type'] == 'income' && !['initial', 'correction', 'transfer_in', 'loan_receive'].contains(t['kind']);
  bool isCashOut(J t) => t['type'] == 'expense' && !['initial', 'correction', 'transfer_out'].contains(t['kind']);

  // ---- loans: their own agreed exchange rates (same as the web app)
  double lconv(J l, num v, String from, String to) {
    final x = v.toDouble();
    if (from == to || x == 0) return x;
    final c = (l['currency'] ?? base).toString();
    final rr = l['rates'];
    final R = rr is Map ? rr : const {};
    double? r(String k) => R[k] == null ? null : (toD(R[k]) == 0 ? null : toD(R[k]));
    if (from == c && r(to) != null) return x * r(to)!;
    if (to == c && r(from) != null) return x / r(from)!;
    if (r(from) != null && r(to) != null) return x / r(from)! * r(to)!;
    if (r(from) != null) return conv(x / r(from)!, c, to);
    if (r(to) != null) return conv(x, from, c) * r(to)!;
    return conv(x, from, to);
  }

  J? _loanOfTx(J t) {
    final k = t['kind'];
    if (k != 'loan_receive' && k != 'loan_pay' && k != 'bank_fee') return null;
    for (final l in loans) {
      final rr = l['rates'];
      if (rr is! Map || rr.isEmpty) continue;
      final pays = (l['payments'] as List?) ?? const [];
      for (final p in pays) {
        if (p is Map && (p['txId'] == t['id'] || p['feeTxId'] == t['id'])) return l;
      }
      if (k == 'loan_receive') {
        final link = t['link'];
        if (link is Map && link['loan'] == l['id']) return l;
        if (link is! Map && t['who'] == l['name']) return l;
      }
    }
    return null;
  }

  /// value of a transaction in the main currency
  double tBase(J t) {
    final l = _loanOfTx(t);
    final from = accCur(t['accId']);
    return l != null ? lconv(l, toD(t['amount']), from, base) : conv(toD(t['amount']), from, base);
  }

  ({double inc, double exp, double cin, double cout}) stats(String from, String to) {
    double inc = 0, exp = 0, cin = 0, cout = 0;
    for (final t in txns) {
      final d = (t['date'] ?? '').toString();
      if (d.compareTo(from) < 0 || d.compareTo(to) > 0) continue;
      final a = acc(t['accId']);
      if (!(a?['include'] != false || a?['type'] == 'credit')) continue;
      final v = tBase(t);
      if (isInc(t)) inc += v;
      if (isExp(t)) exp += v;
      if (isCashIn(t)) cin += v;
      if (isCashOut(t)) cout += v;
    }
    return (inc: inc, exp: exp, cin: cin, cout: cout);
  }

  static const kindInfo = <String, (String, String)>{
    'initial': ('Initial Balance', '💰'),
    'correction': ('Balance Correction', '💰'),
    'transfer_in': ('Transfer In', '🔁'),
    'transfer_out': ('Transfer Out', '🔁'),
    'lend_give': ('Give Lending', '🤲'),
    'lend_receive': ('Receive Lending', '🤲'),
    'loan_receive': ('Loan', '🏦'),
    'loan_pay': ('Loan Payment', '🏦'),
    'bank_fee': ('Bank Fee', '🏛️'),
    'card_pay': ('Card Payment', '💳'),
    'fx_gain': ('Exchange Gain', '💱'),
    'fx_loss': ('Exchange Loss', '💱'),
    'goal': ('Goal Saving', '🎯'),
    'inst': ('Installment', '🧾'),
  };
  static const _noCatTitle = ['transfer_in', 'transfer_out', 'initial', 'correction', 'lend_give', 'lend_receive', 'loan_receive', 'loan_pay', 'bank_fee', 'card_pay'];

  String txTitle(J t) {
    final c = cat(t['catId']);
    if (c != null && !_noCatTitle.contains(t['kind'])) return (c['name'] ?? '').toString();
    final k = kindInfo[t['kind']];
    final who = t['who'];
    return '${k?.$1 ?? 'Transaction'}${who != null && '$who'.isNotEmpty ? ' - $who' : ''}';
  }

  String txIcon(J t) {
    final c = cat(t['catId']);
    final k = kindInfo[t['kind']];
    if (c != null && k == null) return (c['icon'] ?? '💸').toString();
    if (k != null) return k.$2;
    return (c?['icon'] ?? '💸').toString();
  }

  /// Plain income/expense entries can be edited here. Entries created by loans, transfers,
  /// subscriptions etc. are linked to other records, so they are edited in those sections.
  bool canEdit(J t) => t['kind'] == null || t['kind'] == 'normal';

  // ================================================================= changes
  void saveTx(J t) {
    final list = data['txns'] as List;
    final i = list.indexWhere((x) => x is Map && x['id'] == t['id']);
    if (i >= 0) {
      final old = Map<String, dynamic>.from(list[i] as Map);
      list[i] = {...old, ...t}; // keep any field this app doesn't know
    } else {
      list.add(t);
    }
    commit();
  }

  void deleteTx(String id) {
    (data['txns'] as List).removeWhere((x) => x is Map && x['id'] == id);
    commit();
  }

  /// Add or edit a wallet. Same balance rules as the web app (initial / correction entries).
  void saveWallet({String? id, required String name, required String currency, required double balance}) {
    final list = data['accounts'] as List;
    final tx = data['txns'] as List;
    if (id != null) {
      final a = acc(id);
      if (a == null) return;
      a['name'] = name;
      a['currency'] = currency;
      final cb = accBal(a);
      if ((balance - cb).abs() > 0.004) {
        J? initial;
        bool others = false;
        for (final t in txns) {
          if (t['accId'] != id) continue;
          if (t['kind'] == 'initial') {
            initial ??= t;
          } else {
            others = true;
          }
        }
        final d = balance - cb;
        if (initial != null && !others) {
          initial['amount'] = balance.abs();
          initial['type'] = balance >= 0 ? 'income' : 'expense';
        } else {
          tx.add({'id': uid(), 'type': d > 0 ? 'income' : 'expense', 'kind': 'correction', 'accId': id, 'amount': round2(d.abs()), 'date': today(), 'time': nowTime(), 'note': 'Balance updated in account settings', 'tags': []});
        }
      }
    } else {
      final nid = uid();
      list.add({'id': nid, 'name': name, 'currency': currency, 'type': 'wallet', 'include': true, 'isDefault': wallets.isEmpty});
      if (balance != 0) {
        tx.add({'id': uid(), 'type': balance > 0 ? 'income' : 'expense', 'kind': 'initial', 'accId': nid, 'amount': round2(balance.abs()), 'date': today(), 'time': nowTime(), 'note': '', 'tags': []});
      }
    }
    commit();
  }

  void setTheme(String mode) {
    settings['theme'] = mode;
    commit();
  }
}

class AppConfigUrls {
  static const redirect = 'https://dilka-321.github.io/Salli-app-V2/';
}
