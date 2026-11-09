import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/loans.dart';
import '../core/round7.dart';
import '../core/store.dart';
import '../core/util.dart';

/// Sends Salli's due reminders (bills, loans, lendings, subscriptions, installments, cards, to-dos…)
/// to the phone's notification panel:
/// - when the app opens / comes back, every reminder in the in-app list that wasn't sent today is shown;
/// - upcoming due dates (next 7 days) are scheduled for 9:00 AM on that day, so they arrive even when the app is closed.
class PhoneNotify with WidgetsBindingObserver {
  PhoneNotify._();
  static final PhoneNotify I = PhoneNotify._();

  final _plugin = FlutterLocalNotificationsPlugin();
  AppStore? _s;
  bool _ready = false, _busy = false;
  Timer? _debounce;

  static const _channel = AndroidNotificationDetails(
    'salli_due',
    'Due reminders',
    channelDescription: 'Bills, loans, lendings, subscriptions and other due reminders',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _channel);

  /// Call once after the store is loaded.
  Future<void> start(AppStore s) async {
    if (_s != null) return;
    _s = s;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    WidgetsBinding.instance.addObserver(this);
    s.addListener(_onChange);
    await sync();
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), sync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) sync();
  }

  int _id(String k) => (k.hashCode & 0x3fffffff) + 1000;

  Future<void> sync() async {
    final s = _s;
    if (s == null || !_ready || _busy || s.settings['phoneNotify'] == false) return;
    _busy = true;
    try {
      final t = today();
      // ---- reminders shown right now (once per day each)
      final sentKey = 'phoneNotifSent';
      final raw = s.prefs.getStringList(sentKey) ?? const <String>[];
      final sent = raw.where((x) => x.startsWith('$t|')).toSet();
      var added = false;
      for (final n in s.notifications()) {
        final k = '$t|${n.title}';
        if (sent.contains(k)) continue;
        await _plugin.show(id: _id(n.title), title: n.title, body: n.sub, notificationDetails: _details);
        sent.add(k);
        added = true;
      }
      if (added || raw.length != sent.length) await s.prefs.setStringList(sentKey, sent.toList());

      // ---- upcoming due dates at 9:00 AM on the day
      await _plugin.cancelAllPendingNotifications();
      final now = DateTime.now();
      for (final d in s.dueItems()) {
        if (d.days <= 0) continue;
        final day = DateTime.now().add(Duration(days: d.days));
        final at = DateTime(day.year, day.month, day.day, 9);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _id('due:${d.key}'),
          title: '${d.name} is due today',
          body: '${d.kind} · ${d.amt}',
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // notifications are best-effort; never break the app
    } finally {
      _busy = false;
    }
  }
}
