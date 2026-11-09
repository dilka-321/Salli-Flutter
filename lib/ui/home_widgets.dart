import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/loans.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'assets_screens.dart';
import 'budget_screens.dart';
import 'installments_screens.dart';
import 'loans_screens.dart';
import 'plans_common.dart';
import 'recurring_screens.dart';
import 'subs_screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// The optional Home widgets (Customize Dashboard), same content as the web app's.
class HomeWidget extends StatelessWidget {
  const HomeWidget({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    void go(Widget w) => Navigator.of(context).push(pageRoute(w));
    Widget card({required String title, String? action, VoidCallback? onTap, required List<Widget> children}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            onTap: onTap,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                if (action != null) Text(action, style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );
    Widget line(String a, String b, {Color? c, String? sub}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)), if (sub != null) Text(sub, style: TextStyle(color: p.muted, fontSize: 12))])),
            Text(b, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
          ]),
        );
    final mk = ym(today());

    switch (id) {
      case 'fds':
        {
        final L = s.assets.where(s.isFD).toList();
        if (L.isEmpty) return const SizedBox.shrink();
        return card(title: 'Fixed Deposits', action: 'View', onTap: () => go(const AssetsScreen()), children: [
          line('${L.length} deposit${L.length > 1 ? 's' : ''} · total', moneyB(s, L.fold(0.0, (a, x) => a + s.assetBase(x))), c: p.pos),
          for (final a in L.take(3)) line('${a['name']}', s.fdNext(a) != null ? 'next ${fmtDate(s.fdNext(a)!)}' : 'matured', sub: '${toD(s.fdOf(a)['rate']).toStringAsFixed(2)}% · ${money(s.fdMonthly(a), '${s.fdOf(a)['currency'] ?? s.base}')}/month'),
        ]);
        }
      case 'trend':
        return const Padding(padding: EdgeInsets.only(bottom: 14), child: TrendCard());
      case 'budget':
        {
          if (s.budgets.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(children: [
                  const Expanded(child: Text('Monthly Budgeting', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  GestureDetector(onTap: () => go(const BudgetTab()), child: Text('See all', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600))),
                ]),
              ),
              tileGrid([
                for (final b in s.budgets.take(4))
                  Builder(builder: (_) {
                    final amt = toD(b['amount']), sp = s.budgetSpent(b);
                    final q = amt > 0 ? sp / amt : 0.0;
                    final c = q >= 1 ? p.neg : q >= .8 ? p.warn : p.pos;
                    return GlassCard(
                      onTap: () => go(BudgetViewScreen(id: '${b['id']}')),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${b['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700))),
                          Badge2(q >= 1 ? 'Over' : q >= .8 ? 'Warning' : 'Safe', color: c),
                        ]),
                        const SizedBox(height: 6),
                        Text('${(q * 100).round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        ProgressBar(q, color: c, height: 5),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(q >= 1 ? '${moneyB(s, sp - amt)} over' : '${moneyB(s, amt - sp)} left', style: TextStyle(color: p.muted, fontSize: 12)))),
                          const SizedBox(width: 4),
                          Badge2(_cap('${b['period'] ?? 'monthly'}'), color: p.muted),
                        ]),
                      ]),
                    );
                  }),
              ]),
            ]),
          );
        }
      case 'subs':
        {
        final L = s.subs.where((x) => x['active'] != false).toList()..sort((a, b) => '${a['next']}'.compareTo('${b['next']}'));
        if (L.isEmpty) return const SizedBox.shrink();
        return card(title: 'Upcoming Subscriptions', action: 'View all', onTap: () => go(const SubsScreen()), children: [
          for (final x in L.take(3))
            InkWell(
              onTap: () => go(SubDetailScreen(id: '${x['id']}')),
              child: line('${x['name']}', money(toD(x['amount']), '${x['currency'] ?? s.base}'),
                  sub: '${'${x['next']}'.compareTo(today()) < 0 ? 'Overdue · ' : ''}${fmtDate('${x['next']}')}'),
            ),
        ]);
        }
      case 'inst':
        {
        final L = s.installments.where((x) => s.instRemain(x) > 0).toList();
        if (L.isEmpty) return const SizedBox.shrink();
        return card(title: 'Installment Overview', action: 'View', onTap: () => go(const InstallmentsScreen()), children: [
          line('Total outstanding', moneyB(s, L.fold(0.0, (a, x) => a + s.instRemain(x)))),
          for (final x in L.take(2)) line('${x['title']} · next ${fmtDate(s.instNext(x) ?? today())}', moneyB(s, toD(x['amount']))),
        ]);
        }
      case 'loan':
        {
        final L = s.loans.where((l) => s.loanRemain(l) > 0).toList();
        if (L.isEmpty) return const SizedBox.shrink();
        return card(title: 'Loan Overview', action: 'View', onTap: () => go(const LoansScreen()), children: [
          line('${L.length} active loan${L.length > 1 ? 's' : ''} · remaining', moneyB(s, L.fold(0.0, (a, l) => a + s.loanRemainB(l))), c: p.neg),
          for (final l in L.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(children: [
                line('${l['name']}', 'EMI ${money(s.emiOf(l), s.lcur(l))}'),
                ProgressBar(s.loanTotal(l) > 0 ? s.loanPaid(l) / s.loanTotal(l) : 0, color: const Color(0xFF5B8DEF), height: 6),
              ]),
            ),
        ]);
        }
      case 'expense':
        {
        final m = <String, double>{};
        var tot = 0.0;
        for (final t in s.statList(monthStart(mk), monthEnd(mk)).where(s.isExp)) {
          m['${t['catId']}'] = (m['${t['catId']}'] ?? 0) + s.tBase(t);
          tot += s.tBase(t);
        }
        if (m.isEmpty) return const SizedBox.shrink();
        final L = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return card(title: 'Expense Summary', children: [
          for (final e in L.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                line('${s.cat(e.key)?['icon'] ?? ''} ${s.cat(e.key)?['name'] ?? 'Other'}', moneyB(s, e.value)),
                ProgressBar(tot > 0 ? e.value / tot : 0, color: p.accent, height: 6),
              ]),
            ),
        ]);
        }
      case 'standing':
        {
        if (s.recurring.isEmpty) return const SizedBox.shrink();
        return card(title: 'Standing Orders', action: 'View all', onTap: () => go(const RecurringScreen()), children: [
          for (final r in s.recurring.take(3))
            line('${s.cat(r['catId']?.toString())?['icon'] ?? ''} ${'${r['title'] ?? ''}'.isNotEmpty ? r['title'] : s.cat(r['catId']?.toString())?['name'] ?? ''} · ${fmtDate('${r['next']}')}', money(toD(r['amount']), s.accCur(r['accId']?.toString()))),
        ]);
        }
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Simple animated bar chart (one bar per value). [values2] adds a second series drawn beside the first.
class Bars extends StatelessWidget {
  const Bars({super.key, required this.values, required this.color, this.values2, this.color2, this.today = -1});
  final List<double> values;
  final List<double>? values2;
  final Color color;
  final Color? color2;
  final int today;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => CustomPaint(painter: _BarsPainter(values, values2, color, color2 ?? p.pos, t, p.line, today), child: const SizedBox.expand()),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.a, this.b, this.ca, this.cb, this.t, this.line, this.today);
  final List<double> a;
  final List<double>? b;
  final Color ca, cb, line;
  final double t;
  final int today;
  @override
  void paint(Canvas canvas, Size size) {
    final n = a.length;
    if (n == 0) return;
    var mx = a.fold(0.0, math.max);
    if (b != null) mx = math.max(mx, b!.fold(0.0, math.max));
    if (mx <= 0) mx = 1;
    final h = size.height - 4;
    final slot = size.width / n;
    final w = math.max(1.5, slot * (b == null ? .62 : .36));
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), Paint()..color = line);
    for (var i = 0; i < n; i++) {
      final x0 = i * slot + (slot - (b == null ? w : w * 2 + 1)) / 2;
      final ha = a[i] / mx * h * t;
      final pa = Paint()..color = i == today ? ca : ca.withOpacity(.75);
      if (ha > 0) canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x0, size.height - 1 - ha, w, ha), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)), pa);
      if (b != null) {
        final hb = b![i] / mx * h * t;
        if (hb > 0) canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x0 + w + 1, size.height - 1 - hb, w, hb), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)), Paint()..color = cb);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) => o.t != t || o.a != a;
}

String _cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);

/// Spending Trend — Income, Expense, Cash In and Cash Out per day; touch or drag to see each day's figures.
class TrendCard extends StatefulWidget {
  const TrendCard({super.key});
  @override
  State<TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<TrendCard> {
  bool weekly = false;
  int? sel;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final mk = ym(today());
    final days = weekly ? [for (var i = 0; i < 7; i++) addDays(today(), i - 6)] : [for (var i = 1; i <= daysIn(mk); i++) '$mk-${i.toString().padLeft(2, '0')}'];
    final idx = {for (var i = 0; i < days.length; i++) days[i]: i};
    final ser = List.generate(4, (_) => List<double>.filled(days.length, 0));
    for (final t in s.txns) {
      final i = idx['${t['date']}'];
      if (i == null) continue;
      final v = s.tBase(t);
      if (s.isInc(t)) ser[0][i] += v;
      if (s.isExp(t)) ser[1][i] += v;
      if (s.isCashIn(t)) ser[2][i] += v;
      if (s.isCashOut(t)) ser[3][i] += v;
    }
    final names = ['Income', 'Expense', 'Cash In', 'Cash Out'];
    final colors = [p.pos, p.neg, const Color(0xFF7BD8A6), p.warn];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final si = sel != null && sel! < days.length ? sel : null;
    void pick(Offset o, double w) {
      const pl = 38.0;
      final n = days.length;
      final i = n == 1 ? 0 : (((o.dx - pl) / (w - pl - 6)) * (n - 1)).round().clamp(0, n - 1).toInt();
      if (i != sel) {
        HapticFeedback.selectionClick();
        setState(() => sel = i);
      }
    }

    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Spending Trend', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          DropdownButton<bool>(
            value: weekly,
            underline: const SizedBox.shrink(),
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            items: const [DropdownMenuItem(value: false, child: Text('Monthly')), DropdownMenuItem(value: true, child: Text('Weekly'))],
            onChanged: (v) => setState(() {
              weekly = v ?? false;
              sel = null;
            }),
          ),
        ]),
        Wrap(spacing: 12, children: [
          for (var k = 0; k < 4; k++)
            Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[k], shape: BoxShape.circle)), const SizedBox(width: 4), Text(names[k], style: TextStyle(color: p.muted, fontSize: 11.5))]),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (c, box) {
          final w = box.maxWidth;
          return GestureDetector(
            onTapDown: (d) => pick(d.localPosition, w),
            onHorizontalDragStart: (d) => pick(d.localPosition, w),
            onHorizontalDragUpdate: (d) => pick(d.localPosition, w),
            onLongPressMoveUpdate: (d) => pick(d.localPosition, w),
            child: SizedBox(
              height: 190,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) => CustomPaint(
                      painter: _TrendPainter(ser, colors, t, si, p.line, p.muted, p.bg, p.accent, weekly ? [for (final d in days) wd[parseDate(d).weekday - 1]] : null),
                    ),
                  ),
                ),
                if (si != null)
                  Positioned(
                    top: 4,
                    left: (() {
                      const pl = 38.0;
                      final x = pl + (w - pl - 6) * (days.length == 1 ? 0 : si / (days.length - 1));
                      return x > w / 2 ? x - 128 : x + 10;
                    })(),
                    child: IgnorePointer(
                      child: Container(
                        width: 118,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.line), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 10)]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          for (var k = 0; k < 4; k++) ...[
                            Text(names[k], style: TextStyle(color: colors[k], fontSize: 10.5)),
                            Text(moneyB(s, ser[k][si]), style: TextStyle(color: colors[k], fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ],
                          const SizedBox(height: 2),
                          Text(fmtDate(days[si]), style: TextStyle(color: p.muted, fontSize: 10.5)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.ser, this.colors, this.t, this.sel, this.line, this.muted, this.bg, this.accent, this.labels);
  final List<List<double>> ser;
  final List<Color> colors;
  final double t;
  final int? sel;
  final Color line, muted, bg, accent;
  final List<String>? labels;

  String _compact(double v) => v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)}M' : v >= 1e3 ? '${(v / 1e3).toStringAsFixed(v >= 1e4 ? 0 : 1)}K' : v.toStringAsFixed(0);

  @override
  void paint(Canvas canvas, Size size) {
    const pl = 38.0, pb = 20.0, pt = 8.0;
    final n = ser[0].length;
    var mx = 1.0;
    for (final l in ser) {
      for (final v in l) {
        if (v > mx) mx = v;
      }
    }
    double x(int i) => pl + (size.width - pl - 6) * (n == 1 ? 0 : i / (n - 1));
    double y(double v) => pt + (size.height - pt - pb) * (1 - v / mx * t);
    final gp = Paint()..color = line;
    for (var i = 0; i <= 3; i++) {
      final v = mx * i / 3;
      final yy = pt + (size.height - pt - pb) * (1 - i / 3);
      canvas.drawLine(Offset(pl, yy), Offset(size.width, yy), gp);
      final tp = TextPainter(text: TextSpan(text: _compact(v), style: TextStyle(color: muted, fontSize: 9.5)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pl - 5 - tp.width, yy - tp.height / 2));
    }
    final ticks = labels != null ? List.generate(n, (i) => i) : [0, 4, 9, 14, 19, 24, n - 1].where((i) => i < n).toSet().toList();
    for (final i in ticks) {
      final tp = TextPainter(text: TextSpan(text: labels != null ? labels![i] : '${i + 1}', style: TextStyle(color: muted, fontSize: 9.5)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, size.height - tp.height));
    }
    for (var k = 0; k < ser.length; k++) {
      final pts = [for (var i = 0; i < n; i++) Offset(x(i), y(ser[k][i]))];
      canvas.drawPath(_smooth(pts, y(0)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colors[k]);
    }
    if (sel != null) {
      final xx = x(sel!);
      canvas.drawLine(Offset(xx, pt), Offset(xx, size.height - pb), Paint()
        ..color = accent
        ..strokeWidth = 1.4);
      for (var k = 0; k < ser.length; k++) {
        final c = Offset(xx, y(ser[k][sel!]));
        canvas.drawCircle(c, 5.2, Paint()..color = bg);
        canvas.drawCircle(c, 4, Paint()..color = colors[k]);
      }
    }
  }

  /// Monotone curve through the points (never dips below the zero line), like the web app.
  Path _smooth(List<Offset> p, double floor) {
    final path = Path();
    if (p.isEmpty) return path;
    path.moveTo(p[0].dx, p[0].dy);
    if (p.length < 3) {
      for (final o in p.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      return path;
    }
    final n = p.length;
    final m = List<double>.generate(n - 1, (i) => (p[i + 1].dy - p[i].dy) / ((p[i + 1].dx - p[i].dx) == 0 ? 1 : (p[i + 1].dx - p[i].dx)));
    final tg = List<double>.filled(n, 0);
    tg[0] = m[0];
    tg[n - 1] = m[n - 2];
    for (var i = 1; i < n - 1; i++) {
      tg[i] = m[i - 1] * m[i] <= 0 ? 0 : (m[i - 1] + m[i]) / 2;
    }
    for (var i = 0; i < n - 1; i++) {
      final dx = (p[i + 1].dx - p[i].dx) / 3;
      final c1 = Offset(p[i].dx + dx, math.min(floor, p[i].dy + tg[i] * dx));
      final c2 = Offset(p[i + 1].dx - dx, math.min(floor, p[i + 1].dy - tg[i + 1] * dx));
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p[i + 1].dx, p[i + 1].dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => true;
}
