import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../core/currency.dart';
import '../core/loans.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'analytics_screen.dart';
import 'home_widgets.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'widgets.dart';

String _short(String d) => fmtDate(d);
String _slash(String d) {
  final x = parseDate(d);
  return '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
}

const _cfgNames = {
  'overview': 'Financial health score',
  'charts': 'Spending charts',
  'behavior': 'Spending behaviour',
  'insights': 'Behavioural insights',
  'income': 'Income breakdown',
  'budget': 'Budget performance',
  'predict': 'Expense prediction',
  'top': 'Top transactions',
  'txlist': 'Transaction list',
  'bank': 'Bank statements',
};

/// Reports tab — History of generated reports, and the generator.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  String tab = 'history';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final reps = ((s.data['reports'] as List?) ?? const []).whereType<Map>().map((e) => e as J).toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Report Transactions'), automaticallyImplyLeading: false),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(onPressed: () => Navigator.of(context).push(pageRoute(const ReportConfigScreen())), icon: const Icon(Icons.description_outlined), label: const Text('New report')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 160), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'history', label: Text('History')), ButtonSegment(value: 'reports', label: Text('Reports'))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        if (tab == 'reports')
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(children: [
              Icon(Icons.bar_chart_rounded, size: 56, color: p.muted),
              const SizedBox(height: 10),
              Text('Generate a comprehensive financial report by tapping the green button below.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: () => Navigator.of(context).push(pageRoute(const ReportConfigScreen())), icon: const Icon(Icons.description_outlined), label: const Text('Generate report')),
            ]),
          )
        else if (reps.isEmpty)
          const EmptyNote('No reports yet\nReports you generate are listed here', icon: Icons.history_rounded)
        else
          for (final r in reps)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(ReportPreviewScreen(from: '${r['from']}', to: '${r['to']}'))),
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(children: [
                  Icon(Icons.description_outlined, color: p.pos),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Financial Summary Report', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('${_short('${r['from']}')} – ${_short('${r['to']}')}${r['at'] != null ? ' · generated ${fmtDate('${r['at']}'.substring(0, 10))}' : ''}', style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  IconButton(onPressed: () => s.deleteReport('${r['id']}'), icon: Icon(Icons.delete_outline, color: p.muted)),
                ]),
              ),
            ),
      ]),
    );
  }
}

class ReportConfigScreen extends StatefulWidget {
  const ReportConfigScreen({super.key});
  @override
  State<ReportConfigScreen> createState() => _ReportConfigScreenState();
}

class _ReportConfigScreenState extends State<ReportConfigScreen> {
  String sel = 'this';
  String from = today(), to = addMonths(today(), 1);

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final mk = ym(today());
    String back(int n) => addMonthsYm(mk, -n);
    final opts = [
      ('this', 'This Month', 'Current month period', monthStart(mk), monthEnd(mk)),
      ('last', 'Last Month', 'Previous month period', monthStart(back(1)), monthEnd(back(1))),
      ('m3', 'Last 3 Months', 'Past 3 months', monthStart(back(2)), monthEnd(mk)),
      ('m6', 'Last 6 Months', 'Past 6 months', monthStart(back(5)), monthEnd(mk)),
      ('m12', 'Last 12 Months', 'Past year in months', monthStart(back(11)), monthEnd(mk)),
    ];
    Widget opt(String v, String l, String sub, String f, String t, {VoidCallback? tap}) {
      final on = sel == v;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          onTap: tap ?? () => setState(() => sel = v),
          gradient: on ? LinearGradient(colors: [p.accent.withOpacity(.16), p.accent.withOpacity(.06)]) : null,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(v == 'custom' ? Icons.date_range_rounded : Icons.calendar_month_rounded, color: on ? p.accent : p.muted),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(fontWeight: FontWeight.w800, color: on ? p.accent : null)), Text(sub, style: TextStyle(color: p.muted, fontSize: 12))])),
            if (f.isNotEmpty) Text('${fmtDate(f).replaceAll(RegExp(r', \d{4}$'), '')} - ${fmtDate(t).replaceAll(RegExp(r', \d{4}$'), '')}', style: TextStyle(color: p.muted, fontSize: 11.5)),
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? p.accent : p.muted),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report by Income & Expense Category')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton(
            onPressed: () {
              var f = from, t = to;
              if (sel != 'custom') {
                final o = opts.firstWhere((o) => o.$1 == sel);
                f = o.$4;
                t = o.$5;
              }
              s.addReport(f, t);
              Navigator.of(context).pushReplacement(pageRoute(ReportPreviewScreen(from: f, to: t)));
            },
            child: const Text('Generate Report'),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Quick Date Options', style: TextStyle(fontWeight: FontWeight.w800))),
        for (final o in opts) opt(o.$1, o.$2, o.$3, o.$4, o.$5),
        opt('custom', 'Custom Date Range', sel == 'custom' ? '${fmtDate(from)} - ${fmtDate(to)}' : 'Select your own dates', '', '', tap: () async {
          final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDateRange: DateTimeRange(start: parseDate(from), end: parseDate(to)));
          if (r != null) {
            setState(() {
              sel = 'custom';
              from = isoDate(r.start);
              to = isoDate(r.end);
            });
          }
        }),
      ]),
    );
  }
}

/// Report preview — the same sections as the web report, drawn natively. (PDF / Excel export comes in round 7.)
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key, required this.from, required this.to});
  final String from, to;

  J _cfg(AppStore s) {
    if (s.settings['exportCfg'] is! Map) {
      s.settings['exportCfg'] = <String, dynamic>{'overview': true, 'charts': true, 'insights': true, 'txlist': true, 'income': true, 'behavior': true, 'top': true, 'budget': true, 'predict': false, 'bank': false, 'bankAccs': <dynamic>[]};
    }
    return s.settings['exportCfg'] as J;
  }

  void _settings(BuildContext context) {
    final s = StoreScope.read(context);
    final cfg = _cfg(s);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final bankAccs = ((cfg['bankAccs'] as List?) ?? const []).map((e) => '$e').toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .8,
          builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            const Text('Export settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            for (final e in _cfgNames.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                value: cfg[e.key] == true,
                onChanged: (v) {
                  set(() => cfg[e.key] = v);
                  s.commit();
                },
              ),
            if (cfg['bank'] == true) ...[
              const Padding(padding: EdgeInsets.only(top: 6, bottom: 4), child: Text('Bank statements for', style: TextStyle(fontWeight: FontWeight.w700))),
              for (final a in s.accounts)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${a['name']} · ${a['currency']}'),
                  value: bankAccs.contains(a['id']),
                  onChanged: (v) {
                    final l = [...bankAccs];
                    if (v == true) {
                      l.add('${a['id']}');
                    } else {
                      l.remove(a['id']);
                    }
                    set(() => cfg['bankAccs'] = <dynamic>[...l]);
                    s.commit();
                  },
                ),
            ],
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cfg = _cfg(s);
    String B(num v) => money(v, s.base);
    final h = s.healthScore(from, to);
    final st = h.st, ps = h.ps;
    final L = s.statList(from, to);
    final exp = L.where(s.isExp).toList(), inc = L.where(s.isInc).toList();
    final by = <String, double>{};
    for (final x in exp) {
      by['${x['catId']}'] = (by['${x['catId']}'] ?? 0) + s.tBase(x);
    }
    final cats = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final net = st.inc - st.exp;
    final nw = s.netWorthDetail();
    final pr = '${_short(from)} - ${_short(to)}';
    const green = Color(0xFF2FAE72), red = Color(0xFFE5484D), amber = Color(0xFFE5A53A);

    Widget page(String title, List<Widget> body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (title.isNotEmpty) ...[
                Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Text(pr, style: TextStyle(color: p.muted, fontSize: 11))]),
                Divider(color: green.withOpacity(.6)),
              ],
              ...body,
            ]),
          ),
        );
    Widget h4(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)));
    Widget row(String a, String b, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400, fontSize: 13.5))), Text(b, style: TextStyle(color: c, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5))]),
        );
    Widget metric(String k, String v, Color c) => GlassCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(color: p.muted, fontSize: 12)), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16)))]));

    final pages = <Widget>[];
    // cover
    pages.add(GlassCard(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E2A1F), Color(0xFF1F8A5B)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FINANCIAL REPORT', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Financial Summary Report', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(pr, style: const TextStyle(color: Colors.white)),
        Text('Prepared for: ${s.settings['name'] ?? 'You'}', style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12)),
      ]),
    ));
    pages.add(const SizedBox(height: 12));
    pages.add(tileGrid([
      metric('Total Income', B(st.inc), green),
      metric('Total Expenses', B(st.exp), red),
      metric(net >= 0 ? 'Net Surplus' : 'Net Deficit', B(net), net >= 0 ? green : red),
      metric('Savings Rate', '${(h.sr * 100).toStringAsFixed(1)}%', h.sr >= 0 ? green : red),
      metric('Cash In', B(st.cin), green),
      metric('Cash Out', B(st.cout), red),
    ]));
    pages.add(const SizedBox(height: 14));
    if (cfg['overview'] == true) {
      pages.add(page('Financial Health Score', [
        Row(children: [
          Container(width: 64, height: 64, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: amber, width: 5)), child: Text('${h.score}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Grade ${h.grade} • ${h.label}', style: const TextStyle(color: Color(0xFFC9830F), fontWeight: FontWeight.w800, fontSize: 15)), Text('Financial Health Score out of 100', style: TextStyle(color: p.muted, fontSize: 12))]),
        ]),
        h4('Score Breakdown'),
        for (final x in h.parts)
          Builder(builder: (_) {
            final q = x.$2 / x.$3;
            final c = q >= .75 ? green : q >= .4 ? amber : red;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(x.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))), Text('${x.$2} / ${x.$3} pts', style: TextStyle(color: c, fontSize: 12.5))]),
                const SizedBox(height: 4),
                ProgressBar(q, color: c, height: 6),
                Text(x.$4, style: TextStyle(color: p.muted, fontSize: 11.5)),
              ]),
            );
          }),
        h4('Recommendations'),
        for (final (i, r) in s.recommendations(h, B).indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 9, backgroundColor: green, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
              const SizedBox(width: 8),
              Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
            ]),
          ),
      ]));
    }
    pages.add(page('Net Worth Statement', [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF0E2A1F), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Net Worth', style: TextStyle(color: Colors.white70, fontSize: 12)), Text(B(nw.net), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Net savings this period', style: TextStyle(color: Colors.white70, fontSize: 11)), Text(B(net), style: TextStyle(color: net >= 0 ? const Color(0xFF7BE0AE) : const Color(0xFFFF8A80), fontWeight: FontWeight.w700))]),
        ]),
      ),
      h4('ASSETS'),
      for (final g in nw.groups) row(g.name, B(g.v)),
      row('Total Assets', B(nw.A), c: green, bold: true),
      h4('LIABILITIES'),
      if (nw.lgroups.isEmpty) Text('No liabilities.', style: TextStyle(color: p.muted)),
      for (final g in nw.lgroups) row(g.name, B(g.v)),
      row('Total Liabilities', B(nw.L), c: red, bold: true),
    ]));
    final incBy = <String, double>{};
    for (final x in inc) {
      incBy['${x['catId']}'] = (incBy['${x['catId']}'] ?? 0) + s.tBase(x);
    }
    pages.add(page('Cash Flow Statement', [
      row('Cash In', B(st.cin), c: green, bold: true),
      row('Cash Out', B(st.cout), c: red, bold: true),
      Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: st.cin - st.cout >= 0 ? green : const Color(0xFFD9555A), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Expanded(child: Text('Net Cash Flow', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), Text(B(st.cin - st.cout), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
      ),
      if (cfg['income'] == true) ...[
        h4('Income'),
        for (final e in incBy.entries) row('${s.cat(e.key)?['name'] ?? 'Other'}', B(e.value)),
        row('Total Income', B(st.inc), c: green, bold: true),
      ],
      h4('Expenses'),
      for (final e in cats) row('${s.cat(e.key)?['name'] ?? 'Other'}', '(${B(e.value)})', c: red),
      row('Total Expenses', B(st.exp), c: red, bold: true),
    ]));
    if (cfg['charts'] == true || cfg['behavior'] == true) {
      final wd = List<double>.filled(7, 0);
      for (final x in exp) {
        wd[parseDate('${x['date']}').weekday - 1] += s.tBase(x);
      }
      final sizes = [
        ('Small', '< ${B(500)}', (double v) => v < 500, green),
        ('Medium', '${B(500)} - ${B(5000)}', (double v) => v >= 500 && v <= 5000, amber),
        ('Large', '> ${B(5000)}', (double v) => v > 5000, red),
      ];
      pages.add(page('Spending Analysis', [
        h4('Category Breakdown'),
        if (cats.isEmpty) Text('No expenses', style: TextStyle(color: p.muted)),
        for (final e in cats) row('${s.cat(e.key)?['name'] ?? 'Other'}', '${B(e.value)} · ${(e.value / st.exp * 100).toStringAsFixed(1)}%'),
        if (cfg['charts'] == true && cats.isNotEmpty) ...[
          h4('Spending by Category'),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(height: 10, child: Row(children: [for (var i = 0; i < cats.length; i++) Expanded(flex: math.max(1, (cats[i].value / st.exp * 1000).round()), child: Container(color: kChartPalette[i % 12]))])),
          ),
        ],
        if (cfg['behavior'] == true) ...[
          h4('Spending by Day of Week'),
          SizedBox(height: 80, child: Bars(values: wd, color: green)),
          Row(children: [for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) Expanded(child: Text(d, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 10.5)))]),
          h4('Transaction Size Distribution'),
          Row(children: [
            for (final z in sizes)
              Expanded(
                child: Builder(builder: (_) {
                  final l = exp.where((x) => z.$3(s.tBase(x))).toList();
                  final v = l.fold(0.0, (a, x) => a + s.tBase(x));
                  return Container(
                    margin: const EdgeInsets.all(3),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: z.$4), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(z.$1, style: TextStyle(color: z.$4, fontWeight: FontWeight.w800)),
                      FittedBox(child: Text(z.$2, style: TextStyle(color: z.$4, fontSize: 11))),
                      Text('${l.length} txns', style: const TextStyle(fontSize: 12)),
                      FittedBox(child: Text(B(v), style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${exp.isNotEmpty ? (l.length / exp.length * 100).toStringAsFixed(1) : '0.0'}%', style: TextStyle(color: p.muted, fontSize: 11)),
                    ]),
                  );
                }),
              ),
          ]),
        ],
      ]));
    }
    if (cfg['budget'] == true) {
      pages.add(page('Budget Performance', [
        if (s.budgets.isEmpty) Text('No budgets set.', style: TextStyle(color: p.muted), textAlign: TextAlign.center),
        for (final b in s.budgets)
          Builder(builder: (_) {
            final sp = s.budgetSpent(b), q = toD(b['amount']) > 0 ? sp / toD(b['amount']) : 0.0;
            final c = q >= 1 ? red : q >= .8 ? amber : green;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: [
                row('${b['name']} (${b['period'] ?? 'monthly'})', '${B(sp)} / ${B(toD(b['amount']))}', c: c),
                ProgressBar(q, color: c, height: 6),
              ]),
            );
          }),
      ]));
    }
    {
      final lp = s.monthlyDebtPayments();
      final debt = s.loans.fold(0.0, (a, l) => a + s.loanRemainB(l)) + s.installments.fold(0.0, (a, x) => a + s.instRemain(x)) + (nw.lgroups.where((g) => g.name == 'Credit Card').firstOrNull?.v ?? 0);
      final mo = lp > 0 ? (debt / lp).ceil() : 0;
      pages.add(page('Debt & Liabilities', [
        tileGrid([
          metric('Debt-to-Income', '${(st.inc != 0 ? debt / st.inc * 100 : 0).toStringAsFixed(1)}%', green),
          metric('Monthly Payments', B(lp), green),
          metric('Months to Debt-Free', debt > 0 ? '$mo months' : 'Debt-free!', green),
        ]),
        const SizedBox(height: 8),
        if (s.loans.isEmpty && s.installments.isEmpty) Text('No debt or liabilities recorded.', style: TextStyle(color: p.muted), textAlign: TextAlign.center),
        for (final l in s.loans) row('${l['name']}', '${B(s.emiOf(l))}/mo · ${B(s.loanRemain(l))} left'),
        for (final x in s.installments) row('${x['title']}', '${B(toD(x['amount']))}/mo · ${B(s.instRemain(x))} left'),
      ]));
    }
    if (cfg['predict'] == true) {
      final ms = [for (var i = 1; i <= 3; i++) addMonthsYm(ym(from), -i)];
      final vals = [for (final k in ms) s.stats(monthStart(k), monthEnd(k)).exp];
      final avg = vals.fold(0.0, (a, v) => a + v) / 3;
      pages.add(page('Expense Prediction', [
        h4('Next month forecast (3-month average)'),
        Text(B(avg), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        for (var i = 0; i < 3; i++) row(fmtMonth(ms[i]), B(vals[i])),
      ]));
    }
    if (cfg['insights'] == true) {
      final days = diffDays(from, to) + 1;
      final nW = math.max(1, (days * 5 / 7).round()), nE = math.max(1, days - nW);
      double sumW(bool Function(DateTime) f) => exp.where((x) => f(parseDate('${x['date']}'))).fold(0.0, (a, x) => a + s.tBase(x));
      final pf = addDays(from, -days), pt = addDays(from, -1);
      String ch(double a, double b) => b != 0 ? '${((a - b) / b.abs() * 100).toStringAsFixed(1)}%' : '—';
      pages.add(page('Behavioral Insights', [
        if (cats.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0E2A1F), borderRadius: BorderRadius.circular(8)),
            child: Text('Your highest spending category this period was "${s.cat(cats.first.key)?['name'] ?? 'Other'}".', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        h4('Period Comparison ($pr vs ${_short(pf)} - ${_short(pt)})'),
        row('Income', '${B(st.inc)} · ${B(ps.inc)} · ${ch(st.inc, ps.inc)}'),
        row('Expenses', '${B(st.exp)} · ${B(ps.exp)} · ${ch(st.exp, ps.exp)}'),
        row('Net Savings', '${B(net)} · ${B(ps.inc - ps.exp)} · ${ch(net, ps.inc - ps.exp)}'),
        h4('Spending Patterns'),
        tileGrid([
          metric('Weekday Avg/Day', B(sumW((d) => d.weekday <= 5) / nW), p.fg),
          metric('Weekend Avg/Day', B(sumW((d) => d.weekday > 5) / nE), p.fg),
          metric('Early Month (1-10)', B(sumW((d) => d.day <= 10)), p.fg),
          metric('Late Month (21-31)', B(sumW((d) => d.day >= 21)), p.fg),
        ]),
      ]));
    }
    if (cfg['top'] == true) {
      final te = (exp.toList()..sort((a, b) => s.tBase(b).compareTo(s.tBase(a)))).take(5).toList();
      final ti = (inc.toList()..sort((a, b) => s.tBase(b).compareTo(s.tBase(a)))).take(5).toList();
      Widget list(List<J> l, Color c) => Column(children: [
            if (l.isEmpty) Text('None', style: TextStyle(color: p.muted)),
            for (final (i, x) in l.indexed) row('${i + 1}. ${_slash('${x['date']}')} · ${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}', B(s.tBase(x)), c: c),
          ]);
      pages.add(page('Top Transactions', [h4('Largest Expenses'), list(te, red), h4('Largest Income'), list(ti, green)]));
    }
    if (cfg['txlist'] == true) {
      final all = [...L]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
      pages.add(page('Transaction List — Appendix', [
        Text('Transactions: ${all.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final x in all.take(150)) row('${_slash('${x['date']}')} · ${s.txTitle(x)} · ${s.accName(x['accId'])}', '${x['type'] == 'income' ? '+' : '-'} ${B(s.tBase(x))}', c: x['type'] == 'income' ? green : red),
        if (all.length > 150) Text('Showing 150 of ${all.length}.', style: TextStyle(color: p.muted)),
      ]));
    }
    if (cfg['bank'] == true) {
      for (final id in ((cfg['bankAccs'] as List?) ?? const []).map((e) => '$e')) {
        final a = s.acc(id);
        if (a == null) continue;
        final c = '${a['currency']}';
        String M(num v) => money(v, c);
        final open = s.txns.where((x) => x['accId'] == id && '${x['date']}'.compareTo(from) < 0).fold(0.0, (v, x) => v + (x['type'] == 'income' ? toD(x['amount']) : -toD(x['amount'])));
        final tl = s.txns.where((x) => x['accId'] == id && '${x['date']}'.compareTo(from) >= 0 && '${x['date']}'.compareTo(to) <= 0).toList()..sort((x, y) => '${x['date']}${x['time'] ?? ''}'.compareTo('${y['date']}${y['time'] ?? ''}'));
        var bal = open;
        final stRows = <Widget>[];
        for (final x in tl) {
          final isCr = x['type'] == 'income';
          bal += isCr ? toD(x['amount']) : -toD(x['amount']);
          stRows.add(row('${_slash('${x['date']}')} · ${'${x['note'] ?? ''}'.isNotEmpty ? x['note'] : s.txTitle(x)}', '${isCr ? '+' : '-'}${M(toD(x['amount']))} · ${M(bal)}', c: isCr ? green : red));
        }
        final dr = tl.where((x) => x['type'] != 'income').fold(0.0, (v, x) => v + toD(x['amount'])), cr = tl.where((x) => x['type'] == 'income').fold(0.0, (v, x) => v + toD(x['amount']));
        pages.add(page('Bank Statement — ${a['name']}', [
          tileGrid([metric('Opening balance', M(open), p.fg), metric('Money out', M(dr), red), metric('Money in', M(cr), green), metric('Closing balance', M(open - dr + cr), p.fg)]),
          const SizedBox(height: 8),
          row('${_slash(from)} · Opening balance', M(open)),
          ...stRows,
          row('Closing balance', M(open - dr + cr), bold: true),
        ]));
      }
    }
    pages.add(Center(child: Text('${AppConfig.appName} • Confidential • Generated on ${_short(today())}', style: TextStyle(color: p.muted, fontSize: 11.5))));

    final text = '${AppConfig.appName} Financial Summary Report\n$pr\n\nTotal income: ${B(st.inc)}\nTotal expenses: ${B(st.exp)}\nNet: ${B(net)}\nSavings rate: ${(h.sr * 100).toStringAsFixed(1)}%\nCash in: ${B(st.cin)} · Cash out: ${B(st.cout)}\nFinancial health score: ${h.score}/100 (Grade ${h.grade} • ${h.label})\nNet worth: ${B(nw.net)}\n\nTop expenses by category:\n${cats.take(8).map((e) => '  ${s.cat(e.key)?['name'] ?? 'Other'}: ${B(e.value)}').join('\n')}';
    return Scaffold(
      appBar: AppBar(title: const Text('Export Preview'), actions: [
        IconButton(
          tooltip: 'Copy summary',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            toast(context, 'Report summary copied');
          },
        ),
        IconButton(tooltip: 'Export settings', icon: const Icon(Icons.tune_rounded), onPressed: () => _settings(context)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: pages),
    );
  }
}
