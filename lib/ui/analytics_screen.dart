import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'home_widgets.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'widgets.dart';

const kChartPalette = [
  Color(0xFF2FAE72), Color(0xFF5B8DEF), Color(0xFFF2A33A), Color(0xFFE5625E), Color(0xFF9B7BF0), Color(0xFF1FB5C9),
  Color(0xFFE56BB0), Color(0xFF8BC34A), Color(0xFFFF8A65), Color(0xFF7986CB), Color(0xFFA1887F), Color(0xFF90A4AE),
];

/// Analytics tab — General · Expense Category · Income Category, month chips or a custom range.
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String tab = 'general';
  String month = ym(today());
  (String, String)? custom;

  (String, String) get range => custom ?? (monthStart(month), monthEnd(month));

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: parseDate(range.$1), end: parseDate(range.$2)),
    );
    if (r != null) setState(() => custom = (isoDate(r.start), isoDate(r.end)));
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final (f, t) = range;
    final months = [for (var i = 0; i < 12; i++) addMonthsYm(ym(today()), -i)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Custom range', icon: const Icon(Icons.date_range_rounded), onPressed: _pickRange)],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 130), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'general', label: Text('General')), ButtonSegment(value: 'expense', label: Text('Expense Category')), ButtonSegment(value: 'income', label: Text('Income Category'))],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final k in months)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(fmtMonth(k)), selected: custom == null && month == k, onSelected: (_) => setState(() {
                    month = k;
                    custom = null;
                  }))),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Badge2('📅 ${fmtDate(f).replaceAll(RegExp(r', \d{4}$'), '')} - ${fmtDate(t).replaceAll(RegExp(r', \d{4}$'), '')}', color: p.pos),
          if (custom != null) IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => custom = null), icon: const Icon(Icons.close_rounded, size: 18)),
        ]),
        const SizedBox(height: 8),
        if (tab == 'general') ..._general(context, s, p, f, t) else ..._cats(context, s, p, f, t, tab == 'expense'),
      ]),
    );
  }

  List<Widget> _general(BuildContext context, AppStore s, Palette p, String f, String t) {
    final L = s.statList(f, t);
    final st = s.stats(f, t);
    final exp = L.where(s.isExp).toList(), inc = L.where(s.isInc).toList();
    final byCat = <String, double>{}, freq = <String, int>{}, accU = <String, int>{}, byAcc = <String, double>{};
    for (final x in exp) {
      final k = '${x['catId']}';
      byCat[k] = (byCat[k] ?? 0) + s.tBase(x);
      freq[k] = (freq[k] ?? 0) + 1;
      byAcc['${x['accId']}'] = (byAcc['${x['accId']}'] ?? 0) + s.tBase(x);
    }
    for (final x in L.where(s.isCashOut)) {
      accU['${x['accId']}'] = (accU['${x['accId']}'] ?? 0) + 1;
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mf = (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;
    final mu = (accU.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).firstOrNull;
    final small = exp.where((x) => s.tBase(x) < 500).length;
    final big = (exp.toList()..sort((a, b) => s.tBase(b).compareTo(s.tBase(a)))).firstOrNull;
    final nd = diffDays(f, t.compareTo(today()) < 0 ? t : today()) + 1;
    Widget tile(IconData i, Color c, String k, String v, Color? vc, String sub) => GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withOpacity(.14), shape: BoxShape.circle), child: Icon(i, color: c, size: 19)),
            const SizedBox(height: 10),
            Text(k, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: vc))),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 11.5)),
          ]),
        );
    final days = <String>[];
    for (var d = f; d.compareTo(t) <= 0 && days.length < 400; d = addDays(d, 1)) {
      days.add(d);
    }
    final ea = [for (final d in days) exp.where((x) => x['date'] == d).fold(0.0, (a, x) => a + s.tBase(x))];
    final ia = [for (final d in days) inc.where((x) => x['date'] == d).fold(0.0, (a, x) => a + s.tBase(x))];
    final items = <(String?, double, Color)>[for (var i = 0; i < math.min(8, cats.length); i++) (cats[i].key, cats[i].value, kChartPalette[i % 12])];
    if (cats.length > 8) items.add((null, cats.skip(8).fold(0.0, (a, x) => a + x.value), kChartPalette[11]));
    final accs = byAcc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      const Row(children: [Icon(Icons.bar_chart_rounded, size: 20), SizedBox(width: 6), Text('Spending Highlights', style: TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 8),
      tileGrid([
        tile(Icons.account_balance_wallet_outlined, p.pos, 'Total Income', moneyB(s, st.inc), p.pos, 'Total earned'),
        tile(Icons.south_west_rounded, p.pos, 'Cash In', moneyB(s, st.cin), p.pos, 'Total earned'),
        tile(Icons.receipt_outlined, p.neg, 'Total Spent', moneyB(s, st.exp), p.neg, 'Total expenses'),
        tile(Icons.north_east_rounded, p.neg, 'Cash Out', moneyB(s, st.cout), p.neg, 'Total expenses'),
        tile(Icons.repeat_rounded, p.pos, 'Most Frequent', mf != null ? '${s.cat(mf.key)?['name'] ?? '—'}' : 'None', p.pos, '${mf?.value ?? 0} transactions'),
        tile(Icons.credit_card_rounded, const Color(0xFF9B7BF0), 'Most Used Account', mu != null ? s.accName(mu.key) : '—', null, 'Primary payment method'),
        tile(Icons.emoji_events_outlined, p.warn, 'Top Category', cats.isNotEmpty ? '${s.cat(cats.first.key)?['name'] ?? ''}' : '—', p.warn, '${cats.isNotEmpty && st.exp > 0 ? (cats.first.value / st.exp * 100).toStringAsFixed(1) : '0.0'}% of expenses'),
        tile(Icons.receipt_long_rounded, const Color(0xFF5B8DEF), 'Small Payments', '$small', const Color(0xFF5B8DEF), '< ${moneyB(s, 500)}'),
        tile(Icons.calendar_month_rounded, const Color(0xFF5B8DEF), 'Avg. Daily Spend', moneyB(s, st.exp / math.max(1, nd)), null, 'Over $nd days'),
        tile(Icons.north_east_rounded, p.neg, 'Largest Expense', big != null ? moneyB(s, s.tBase(big)) : '—', p.neg, big != null ? s.txTitle(big) : 'No expenses'),
      ]),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.bar_chart_rounded, size: 20), SizedBox(width: 6), Text('Daily Summary', style: TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          Row(children: [_dot(p.neg), const Text(' Expense   ', style: TextStyle(fontSize: 12)), _dot(p.pos), const Text(' Income', style: TextStyle(fontSize: 12))]),
          const SizedBox(height: 10),
          SizedBox(height: 150, child: Bars(values: ea, values2: ia, color: p.neg, color2: p.pos)),
          const SizedBox(height: 4),
          Row(children: [Text(days.isEmpty ? '' : '${parseDate(days.first).day}', style: TextStyle(color: p.muted, fontSize: 11)), const Spacer(), Text(days.isEmpty ? '' : '${parseDate(days.last).day}', style: TextStyle(color: p.muted, fontSize: 11))]),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [Icon(Icons.pie_chart_outline_rounded, size: 20), SizedBox(width: 6), Text('Spending Distribution', style: TextStyle(fontWeight: FontWeight.w800))]),
          if (accs.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('No spending data available for the selected period', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontStyle: FontStyle.italic, fontSize: 13))),
          for (final e in accs)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(children: [
                Row(children: [Expanded(child: Text(s.accName(e.key), style: const TextStyle(fontSize: 13.5))), Text('${moneyB(s, e.value)} · ${(e.value / st.exp * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                const SizedBox(height: 4),
                ProgressBar(st.exp > 0 ? e.value / st.exp : 0, color: const Color(0xFF5B8DEF), height: 6),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      const Row(children: [Icon(Icons.donut_large_rounded, size: 20), SizedBox(width: 6), Text('Spending by Category', style: TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 8),
      GlassCard(
        child: Column(children: [
          if (items.isEmpty)
            Text('No expenses in this period', style: TextStyle(color: p.muted))
          else ...[
            SizedBox(
              height: 210,
              child: Stack(alignment: Alignment.center, children: [
                PieDonut(parts: [for (final it in items) (it.$2, it.$3)]),
                Column(mainAxisSize: MainAxisSize.min, children: [Text('Total', style: TextStyle(color: p.muted, fontSize: 12)), Text(moneyB(s, st.exp), style: const TextStyle(fontWeight: FontWeight.w800))]),
              ]),
            ),
            const SizedBox(height: 10),
            for (final it in items)
              InkWell(
                onTap: it.$1 == null ? null : () => Navigator.of(context).push(pageRoute(CategoryTxScreen(catId: it.$1!, from: f, to: t, income: false))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: it.$3, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(it.$1 != null ? '${s.cat(it.$1)?['name'] ?? 'Other'}' : 'Others')),
                    Text('${(it.$2 / st.exp * 100).toStringAsFixed(1)}%  ', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    Text(moneyB(s, it.$2), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ],
        ]),
      ),
    ];
  }

  Widget _dot(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  List<Widget> _cats(BuildContext context, AppStore s, Palette p, String f, String t, bool isE) {
    final L = s.statList(f, t).where(isE ? s.isExp : s.isInc).toList();
    final tot = L.fold(0.0, (a, x) => a + s.tBase(x));
    final by = <String, (double, int)>{};
    for (final x in L) {
      final k = '${x['catId']}';
      final o = by[k] ?? (0.0, 0);
      by[k] = (o.$1 + s.tBase(x), o.$2 + 1);
    }
    final rows = by.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    if (rows.isEmpty) return [EmptyNote('No ${isE ? 'expense' : 'income'} in this period', icon: Icons.pie_chart_outline_rounded)];
    return [
      tileGrid([
        for (final e in rows)
          GlassCard(
            onTap: () => Navigator.of(context).push(pageRoute(CategoryTxScreen(catId: e.key, from: f, to: t, income: !isE))),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('${s.cat(e.key)?['icon'] ?? '📦'}', style: const TextStyle(fontSize: 22)), const Spacer(), Badge2('${(e.value.$1 / tot * 100).toStringAsFixed(1)}%', color: p.pos)]),
              const SizedBox(height: 6),
              Text('${s.cat(e.key)?['name'] ?? 'Uncategorised'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(moneyB(s, e.value.$1), style: TextStyle(fontWeight: FontWeight.w800, color: isE ? p.neg : p.pos))),
              Text('${e.value.$2} txn${e.value.$2 > 1 ? 's' : ''}', style: TextStyle(color: p.muted, fontSize: 11.5)),
              const SizedBox(height: 6),
              ProgressBar(tot > 0 ? e.value.$1 / tot : 0, color: p.pos, height: 5),
            ]),
          ),
      ]),
    ];
  }
}

/// Animated donut of several parts.
class PieDonut extends StatelessWidget {
  const PieDonut({super.key, required this.parts});
  final List<(double, Color)> parts;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tot = parts.fold(0.0, (a, x) => a + x.$1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(painter: _PiePainter(parts, tot == 0 ? 1 : tot, v, p.fg.withOpacity(.08)), child: const SizedBox.expand()),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.parts, this.total, this.t, this.track);
  final List<(double, Color)> parts;
  final double total, t;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 - 16;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    canvas.drawCircle(rect.center, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = track);
    var a = -math.pi / 2;
    for (final x in parts) {
      final sw = x.$1 / total * math.pi * 2 * t;
      canvas.drawArc(rect, a, sw, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = x.$2);
      a += sw;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter o) => o.t != t || o.total != total;
}

/// Transactions of one category in a date range (drill-down from Analytics).
class CategoryTxScreen extends StatelessWidget {
  const CategoryTxScreen({super.key, required this.catId, required this.from, required this.to, required this.income});
  final String catId, from, to;
  final bool income;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.statList(from, to).where((x) => (income ? s.isInc(x) : s.isExp(x)) && x['catId'] == catId).toList();
    final tot = L.fold(0.0, (a, x) => a + s.tBase(x));
    return Scaffold(
      appBar: AppBar(title: Text('${s.cat(catId)?['icon'] ?? ''} ${s.cat(catId)?['name'] ?? 'Category'}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(child: kvRow(p, '${fmtDate(from)} – ${fmtDate(to)}', moneyB(s, tot), color: income ? p.pos : p.neg, sub: '${L.length} transactions')),
        const SizedBox(height: 10),
        if (L.isEmpty) const EmptyNote('No transactions.') else TxGroups(list: L, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
}
