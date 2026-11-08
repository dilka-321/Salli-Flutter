import 'dart:math';

final Random _rnd = Random();

/// Same id style as the web app: time in base 36 + 5 random base-36 chars.
String uid() {
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final r = List.generate(5, (_) => _rnd.nextInt(36).toRadixString(36)).join();
  return '$t$r';
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// 'YYYY-MM-DD'
String isoDate(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';
String today() => isoDate(DateTime.now());

/// 'HH:MM:SS'
String nowTime() {
  final d = DateTime.now();
  return '${_p2(d.hour)}:${_p2(d.minute)}:${_p2(d.second)}';
}

DateTime parseDate(String s) {
  try {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  } catch (_) {
    return DateTime.now();
  }
}

/// 'YYYY-MM'
String ym(String date) => date.length >= 7 ? date.substring(0, 7) : date;
String monthStart(String ymKey) => '$ymKey-01';
String monthEnd(String ymKey) {
  final p = ymKey.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0);
  return isoDate(d);
}

String addMonthsYm(String ymKey, int n) {
  final p = ymKey.split('-');
  final d = DateTime(int.parse(p[0]), int.parse(p[1]) + n, 1);
  return '${d.year}-${_p2(d.month)}';
}

double round2(num v) => (v * 100).roundToDouble() / 100;

double toD(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 'Nov 8, 2026'
String fmtDate(String iso) {
  final d = parseDate(iso);
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// 'Nov 2026'
String fmtMonth(String ymKey) {
  final p = ymKey.split('-');
  return '${_months[int.parse(p[1]) - 1]} ${p[0]}';
}

String weekday(String iso) => _days[parseDate(iso).weekday - 1];

/// 'HH:MM' from 'HH:MM[:SS]', shown as 2:05 PM
String fmtTime(String? t) {
  if (t == null || t.length < 4) return '';
  final p = t.split(':');
  var h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? p[1] : '00';
  final am = h < 12;
  h = h % 12 == 0 ? 12 : h % 12;
  return '$h:$m ${am ? 'AM' : 'PM'}';
}
