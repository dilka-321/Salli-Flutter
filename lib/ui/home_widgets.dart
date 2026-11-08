import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/loans.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'assets_screens.dart';
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
        {
        final n = daysIn(mk);
        final vals = List<double>.filled(n, 0);
        for (final t in s.statList(monthStart(mk), monthEnd(mk))) {
          if (s.isExp(t)) vals[int.parse('${t['date']}'.substring(8, 10)) - 1] += s.tBase(t);
        }
        final tot = vals.fold(0.0, (a, v) => a + v);
        if (tot == 0) return const SizedBox.shrink();
        return card(title: 'Spending Trend', children: [
          Text('${moneyB(s, tot)} spent in ${fmtMonth(mk)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          SizedBox(height: 110, child: Bars(values: vals, color: p.neg, today: mk == ym(today()) ? parseDate(today()).day - 1 : -1)),
        ]);
        }
      case 'budget':
        {
        if (s.budgets.isEmpty) return const SizedBox.shrink();
        return card(title: 'Budget Progress', children: [
          for (final b in s.budgets.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [
                line('${b['name']}', '${moneyB(s, s.budgetSpent(b))} / ${moneyB(s, toD(b['amount']))}'),
                ProgressBar(toD(b['amount']) > 0 ? s.budgetSpent(b) / toD(b['amount']) : 0, height: 6),
              ]),
            ),
        ]);
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
