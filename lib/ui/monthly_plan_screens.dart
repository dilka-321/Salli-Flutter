import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/ops.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

String _fML(String k) {
  const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final p = k.split('-');
  return '${m[int.parse(p[1]) - 1]} ${p[0]}';
}

const _secs = [
  ('expenses', 'Monthly Expenses', 'Expenses', Icons.calendar_view_month_rounded, 'No expenses yet. Tap "+" to choose categories.', 'Add Expense'),
  ('loans', 'Loan Payments', 'Loan Payments', Icons.account_balance_rounded, 'No loan payments yet. Tap "Add Loan" to add one.', 'Add Loan'),
  ('cards', 'Credit Card Payments', 'Credit Card Payments', Icons.credit_card_rounded, 'No credit card payments yet. Tap "Add Card" to add one.', 'Add Card'),
  ('goals', 'Saving Goals', 'Saving Goals', Icons.savings_outlined, 'No saving goals yet. Tap "Add Goal" to add one.', 'Add Goal'),
];

/// (icon, name, sub) for one plan item.
(String, String, String) _label(AppStore s, String k, J x, {bool detail = false}) {
  switch (k) {
    case 'expenses':
      final c = s.cat(x['catId']?.toString());
      return ('${c?['icon'] ?? '📦'}', '${c?['name'] ?? 'Category'}', 'Expenses');
    case 'loans':
      final l = s.loans.where((y) => y['id'] == x['loanId']).firstOrNull;
      if (l == null) return ('🏦', 'Loan', '');
      return ('🏦', '${l['name']}', detail ? 'Remaining ${money(s.loanRemain(l), s.lcur(l))}' : 'EMI ${money(s.emiOf(l), s.lcur(l))}');
    case 'cards':
      final c = s.acc(x['accId']?.toString());
      return ('💳', '${c?['name'] ?? 'Card'}', c == null ? '' : 'Credit Limit: ${money(toD(c['limit']), '${c['currency'] ?? s.base}')}');
    default:
      final g = s.goals.where((y) => y['id'] == x['goalId']).firstOrNull;
      if (g == null) return ('🎯', 'Goal', '');
      return ('${g['icon'] ?? '🎯'}', '${g['name']}', detail ? '${moneyB(s, s.goalSaved(g))} saved' : '${moneyB(s, s.goalSaved(g))} of ${moneyB(s, toD(g['target']))}');
  }
}

String _curNote(AppStore s, J x) => x['cur'] != null && x['cur'] != s.base ? ' · ${money(toD(x['orig']), '${x['cur']}')}' : '';

void _planInfo(BuildContext context) {
  final s = StoreScope.read(context);
  var hide = s.settings['planIntroHide'] == true;
  showDialog(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      Widget row(IconData i, Color col, String t, String d) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: col),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w800)), Text(d, style: TextStyle(color: p.muted, fontSize: 13))])),
            ]),
          );
      return AlertDialog(
        title: const Text('Monthly Plan vs Spending Tracker'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          row(Icons.account_balance_wallet_outlined, p.pos, 'Monthly Plan', 'Plan where your entire salary should go at the start of each month. Allocate money to categories, loans, goals and credit cards.'),
          row(Icons.pie_chart_outline_rounded, p.warn, 'Monthly Budgeting', "Track your actual spending throughout the month. See how much you've spent vs. how much you planned."),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.accent.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [Icon(Icons.lightbulb_outline_rounded, color: p.accent), const SizedBox(width: 8), Expanded(child: Text('Budgets are automatically created from your Monthly Plan category allocations.', style: TextStyle(color: p.accent, fontSize: 13)))]),
          ),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: hide, onChanged: (v) => set(() => hide = v == true), title: const Text("Don't show this again", style: TextStyle(fontSize: 14))),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              s.setPlanIntroHide(hide);
              Navigator.pop(c);
            },
            child: const Text('Got it'),
          ),
        ],
      );
    }),
  );
}

class MonthlyPlansScreen extends StatefulWidget {
  const MonthlyPlansScreen({super.key});
  @override
  State<MonthlyPlansScreen> createState() => _MonthlyPlansScreenState();
}

class _MonthlyPlansScreenState extends State<MonthlyPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && StoreScope.read(context).settings['planIntroHide'] != true) _planInfo(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = [...s.mplans]..sort((a, b) => '${b['month']}'.compareTo('${a['month']}'));
    void create() => Navigator.of(context).push(pageRoute(const PlanEditScreen()));
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Plan'), actions: [
        IconButton(tooltip: 'About plans', icon: const Icon(Icons.info_outline_rounded), onPressed: () => _planInfo(context)),
        IconButton(tooltip: 'Monthly overview', icon: const Icon(Icons.bar_chart_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const PlanOverviewScreen()))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: create, child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        if (L.isEmpty) ...[
          const EmptyNote('No monthly plans yet\nSplit your salary across expenses, loans, cards and savings', icon: Icons.calendar_view_month_rounded),
          Center(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Create Monthly Plan'), onPressed: create)),
        ],
        for (final pl in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final tot = s.planTotal(pl), sp = s.planSpent(pl), a = s.planAlloc(pl);
              final pr = a.exp > 0 ? sp / a.exp : 0.0;
              final inc = toD(pl['income']);
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(PlanDetailScreen(id: '${pl['id']}'))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('${pl['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Text(moneyB(s, inc - tot), style: TextStyle(color: p.pos, fontWeight: FontWeight.w800)),
                  ]),
                  Text(_fML('${pl['month']}'), style: TextStyle(color: p.muted, fontSize: 12.5)),
                  Divider(height: 18, color: p.line),
                  Row(children: [
                    Expanded(child: Text('Total Allocated ${moneyB(s, tot)}', style: TextStyle(color: p.muted, fontSize: 12.5))),
                    Text('${moneyB(s, inc)} Income', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 8),
                  ProgressBar(pr, color: pr > 1 ? p.neg : p.pos),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('${(pr * 100).round()}% ● ${pr > 1 ? 'Over plan' : 'On Track'}', style: TextStyle(color: pr > 1 ? p.neg : p.pos, fontSize: 12.5))),
                    Text('${moneyB(s, inc - tot)} left', style: TextStyle(color: p.pos, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ]),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class PlanOverviewScreen extends StatefulWidget {
  const PlanOverviewScreen({super.key});
  @override
  State<PlanOverviewScreen> createState() => _PlanOverviewScreenState();
}

class _PlanOverviewScreenState extends State<PlanOverviewScreen> {
  String? sel;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = [...s.mplans]..sort((a, b) => '${b['month']}'.compareTo('${a['month']}'));
    if (L.isEmpty) return Scaffold(appBar: AppBar(title: const Text('Monthly Overview')), body: const EmptyNote('No monthly plans yet\nCreate a plan to compare planned and actual spending'));
    final pl = L.where((x) => x['id'] == sel).firstOrNull ?? L.where((x) => x['month'] == ym(today())).firstOrNull ?? L.first;
    final rows = s.planOverview(pl);
    final tot = s.planTotal(pl), act = rows.fold(0.0, (a, r) => a + r.act), inc = toD(pl['income']);
    final secs = <String>[];
    for (final r in rows) {
      if (!secs.contains(r.sec)) secs.add(r.sec);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Overview')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (L.length > 1)
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final x in L) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('${x['name']} · ${fmtMonth('${x['month']}')}'), selected: x['id'] == pl['id'], onSelected: (_) => setState(() => sel = '${x['id']}'))),
            ]),
          ),
        const SizedBox(height: 8),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${pl['name']} · ${_fML('${pl['month']}')}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            kvRow(p, 'Total Salary', moneyB(s, inc), color: p.pos),
            kvRow(p, 'Total Allocated', moneyB(s, tot)),
            kvRow(p, 'Total Actual', moneyB(s, act)),
            kvRow(p, 'Remaining Unallocated', moneyB(s, inc - tot), color: inc - tot < 0 ? p.neg : p.pos),
          ]),
        ),
        if (rows.isEmpty) const EmptyNote('This plan has no allocations yet.'),
        for (final sc in secs) ...[
          SectionTitle(sc),
          for (final r in rows.where((r) => r.sec == sc))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(builder: (_) {
                final q = r.plan != 0 ? r.act / r.plan : 0.0;
                Widget col(String k, String v, CrossAxisAlignment al, {Color? c}) => Expanded(child: Column(crossAxisAlignment: al, children: [Text(k, style: TextStyle(color: p.muted, fontSize: 12)), Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 13))]));
                return GlassCard(
                  child: Column(children: [
                    Row(children: [Expanded(child: Text('${r.icon} ${r.name}', style: const TextStyle(fontWeight: FontWeight.w800))), Badge2('${(q * 100).round()}%', color: q > 1 ? p.neg : p.pos)]),
                    const SizedBox(height: 8),
                    ProgressBar(q, color: q > 1 ? p.neg : p.pos),
                    const SizedBox(height: 8),
                    Row(children: [
                      col('Planned', moneyB(s, r.plan), CrossAxisAlignment.start),
                      col('Actual', moneyB(s, r.act), CrossAxisAlignment.center),
                      col('Remaining', moneyB(s, r.plan - r.act), CrossAxisAlignment.end, c: r.plan - r.act < 0 ? p.neg : p.pos),
                    ]),
                  ]),
                );
              }),
            ),
        ],
      ]),
    );
  }
}

class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final pl = s.mplan(id);
    if (pl == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This plan was deleted.'));
    final a = s.planAlloc(pl), tot = s.planTotal(pl), inc = toD(pl['income']);
    final f = monthStart('${pl['month']}'), t = monthEnd('${pl['month']}');
    final parts = [('Expenses', a.exp, p.neg), ('Loan Payments', a.loan, const Color(0xFF5B8DEF)), ('Credit Card Payments', a.card, p.warn), ('Saving Goals', a.goal, p.accent)].where((x) => x.$2 > 0).toList();
    Widget list(String k, String title) {
      final items = s.planItems(pl, k);
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('$title  ·  ${moneyB(s, items.fold(0.0, (a, x) => a + toD(x['amount'])))}'),
        for (final x in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (_) {
              final l = _label(s, k, x, detail: true);
              double? pr;
              var sub = l.$3;
              if (k == 'expenses') {
                final sp = s.catSpent('${x['catId']}', f, t);
                sub = 'Spent ${moneyB(s, sp)} of ${moneyB(s, toD(x['amount']))}';
                pr = toD(x['amount']) != 0 ? sp / toD(x['amount']) : 0.0;
              }
              return GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  EmojiTile(l.$1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('$sub${_curNote(s, x)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      if (pr != null) Padding(padding: const EdgeInsets.only(top: 6), child: ProgressBar(pr, color: pr > 1 ? p.neg : p.pos, height: 6)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(moneyB(s, toD(x['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              );
            }),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Plan Details'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(pageRoute(PlanEditScreen(existing: pl)))),
        IconButton(
          icon: Icon(Icons.delete_outline, color: p.neg),
          onPressed: () async {
            if (await confirmDialog(context, 'Delete plan?', 'This removes the plan. Budgets created from it stay.')) {
              s.deletePlan(id);
              if (context.mounted) {
                Navigator.pop(context);
                toast(context, 'Salary plan deleted successfully');
              }
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        Text('${pl['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        Text(
          'Total Salary: ${moneyB(s, inc)}${pl['incomeCur'] != null && pl['incomeCur'] != s.base ? ' (${money(toD(pl['incomeOrig']), '${pl['incomeCur']}')})' : ''} · ${_fML('${pl['month']}')}',
          style: TextStyle(color: p.muted),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Remaining Amount', style: TextStyle(color: p.muted)),
            Text(moneyB(s, inc - tot), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: inc - tot < 0 ? p.neg : p.pos)),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          for (final x in [('Expenses', a.exp), ('Loan Payments', a.loan), ('Credit Card Payments', a.card), ('Saving Goals', a.goal)])
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.$1, style: TextStyle(color: p.muted, fontSize: 12.5)), Text(moneyB(s, x.$2), style: const TextStyle(fontWeight: FontWeight.w800))]),
            ),
        ]),
        if (tot > 0) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(children: [
              SizedBox(height: 180, child: _Donut(parts: [for (final x in parts) (x.$2, x.$3)], total: tot)),
              const SizedBox(height: 12),
              Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
                for (final x in parts)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: x.$3, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${x.$1} ${(x.$2 / tot * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12.5)),
                  ]),
              ]),
            ]),
          ),
        ],
        list('expenses', 'Expenses'),
        list('loans', 'Loan Payments'),
        list('cards', 'Credit Card Payments'),
        list('goals', 'Saving Goals'),
      ]),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.parts, required this.total});
  final List<(double, Color)> parts;
  final double total;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => CustomPaint(painter: _DonutPainter(parts, total, v, p.fg.withOpacity(.08)), child: const SizedBox.expand()),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.total, this.t, this.track);
  final List<(double, Color)> parts;
  final double total, t;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide / 2) - 14;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..color = track;
    canvas.drawCircle(rect.center, r, base);
    var a = -1.5708;
    for (final x in parts) {
      final sweep = (x.$1 / total) * 6.28318 * t;
      canvas.drawArc(rect, a, sweep, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..color = x.$2);
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.t != t || o.total != total;
}

/// Create / edit a monthly plan.
class PlanEditScreen extends StatefulWidget {
  const PlanEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<PlanEditScreen> createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends State<PlanEditScreen> {
  final name = TextEditingController();
  final income = TextEditingController();
  String month = ym(today());
  String? incomeCur;
  final items = <String, List<J>>{'expenses': [], 'loans': [], 'cards': [], 'goals': []};
  bool hide = false;
  String? errName, errIncome;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final e = widget.existing;
    incomeCur = s.base;
    if (e != null) {
      name.text = '${e['name'] ?? ''}';
      month = '${e['month'] ?? ym(today())}';
      income.text = plainNum(toD(e['incomeOrig'] ?? e['income']));
      incomeCur = '${e['incomeCur'] ?? s.base}';
      for (final k in items.keys) {
        items[k] = s.planItems(e, k).map((x) => Map<String, dynamic>.from(x)).toList();
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    income.dispose();
    super.dispose();
  }

  /// amount sheet with currency choice → item fields {amount (main currency), orig, cur}
  Future<J?> _ask(String title, {num? init, String? cur}) async {
    final s = StoreScope.read(context);
    final ctl = TextEditingController(text: init != null && init > 0 ? plainNum(round2(init)) : '');
    var c = cur ?? s.base;
    return showModalBottomSheet<J>(
      context: context,
      isScrollControlled: true,
      builder: (sh) => StatefulBuilder(builder: (sh, set) {
        final p = Palette.of(sh);
        final v = parseAmount(ctl.text) ?? 0;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sh).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                AmountBox(controller: ctl, currency: c, autofocus: true, onChanged: (_) => set(() {})),
                const SizedBox(height: 8),
                Row(children: [
                  ActionChip(
                    avatar: const Icon(Icons.currency_exchange_rounded, size: 18),
                    label: Text(c),
                    onPressed: () async {
                      final x = await pickCurrency(sh, c);
                      if (x != null) set(() => c = x);
                    },
                  ),
                  const Spacer(),
                  if (c != s.base && v > 0) Text('≈ ${money(s.conv(v, c, s.base), s.base)}', style: TextStyle(color: p.pos)),
                ]),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final x = parseAmount(ctl.text) ?? 0;
                    if (x <= 0) return Navigator.pop(sh);
                    Navigator.pop(sh, <String, dynamic>{'amount': round2(s.conv(x, c, s.base)), 'orig': x, 'cur': c});
                  },
                  child: const Text('Done'),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Future<String?> _listPicker(String title, List<(String, String, String, String)> rows) => showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final r in rows) ListTile(leading: Text(r.$4, style: const TextStyle(fontSize: 24)), title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(r.$3), onTap: () => Navigator.pop(c, r.$1)),
          ]),
        ),
      );

  Future<void> _add(String k) async {
    final s = StoreScope.read(context);
    if (k == 'expenses') {
      final current = items['expenses']!.map((x) => '${x['catId']}').toList();
      final sel = await _multiCat(current);
      if (sel == null) return;
      final added = sel.where((id) => !current.contains(id)).toList();
      setState(() => items['expenses']!.removeWhere((x) => !sel.contains('${x['catId']}')));
      for (final id in added) {
        if (!mounted) return;
        final r = await _ask('Allocate Amount for ${s.cat(id)?['name'] ?? 'Category'}');
        if (r != null) setState(() => items['expenses']!.add({'catId': id, ...r}));
      }
    } else if (k == 'loans') {
      final L = s.loans.where((l) => s.loanRemain(l) > 0 && !items['loans']!.any((x) => x['loanId'] == l['id'])).toList();
      if (L.isEmpty) return toast(context, 'No active loans available');
      final id = await _listPicker('Select Loan', [for (final l in L) ('${l['id']}', '${l['name']}', 'EMI ${money(s.emiOf(l), s.lcur(l))}', '🏦')]);
      if (id == null || !mounted) return;
      final l = L.firstWhere((x) => x['id'] == id);
      final r = await _ask('Allocate Amount for ${l['name']}', init: round2(s.emiB(l)));
      if (r != null) setState(() => items['loans']!.add({'loanId': id, ...r}));
    } else if (k == 'cards') {
      final L = s.cards.where((c) => !items['cards']!.any((x) => x['accId'] == c['id'])).toList();
      if (L.isEmpty) return toast(context, 'No credit cards available');
      final id = await _listPicker('Select Card', [for (final c in L) ('${c['id']}', '${c['name']}', 'Limit ${money(toD(c['limit']), '${c['currency'] ?? s.base}')}', '💳')]);
      if (id == null || !mounted) return;
      final r = await _ask('Allocate Amount for ${s.accName(id)}');
      if (r != null) setState(() => items['cards']!.add({'accId': id, ...r}));
    } else {
      final L = s.goals.where((g) => g['completed'] != true && !items['goals']!.any((x) => x['goalId'] == g['id'])).toList();
      if (L.isEmpty) return toast(context, 'No active goals available');
      final id = await _listPicker('Select Goal', [for (final g in L) ('${g['id']}', '${g['name']}', '${moneyB(s, s.goalSaved(g))} of ${moneyB(s, toD(g['target']))}', '${g['icon'] ?? '🎯'}')]);
      if (id == null || !mounted) return;
      final r = await _ask('Allocate Amount for ${L.firstWhere((x) => x['id'] == id)['name']}');
      if (r != null) setState(() => items['goals']!.add({'goalId': id, ...r}));
    }
  }

  Future<List<String>?> _multiCat(List<String> current) => showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        builder: (c) {
          final sel = [...current];
          return StatefulBuilder(builder: (c, set) {
            final s = StoreScope.of(c);
            final p = Palette.of(c);
            final mains = s.categories.where((x) => x['kind'] == 'expense' && x['parent'] == null).toList();
            Widget row(J x, bool sub) => CheckboxListTile(
                  contentPadding: EdgeInsets.only(left: sub ? 36 : 4, right: 4),
                  value: sel.contains(x['id']),
                  activeColor: p.accent,
                  onChanged: (v) => set(() {
                    if (v == true) {
                      sel.add('${x['id']}');
                    } else {
                      sel.remove(x['id']);
                    }
                  }),
                  secondary: Text('${x['icon'] ?? '📦'}', style: const TextStyle(fontSize: 22)),
                  title: Text('${x['name']}', style: TextStyle(fontWeight: sub ? FontWeight.w500 : FontWeight.w700)),
                );
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: .8,
              builder: (_, sc) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
                  child: Row(children: [
                    Expanded(child: Text('Categories (${sel.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: () => Navigator.pop(c, sel), child: const Text('Done')),
                  ]),
                ),
                Expanded(
                  child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
                    for (final m in mains) ...[row(m, false), for (final sub in s.categories.where((x) => x['parent'] == m['id'])) row(sub, true)],
                  ]),
                ),
              ]),
            );
          });
        },
      );

  void _itemMenu(String k, int i) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Change amount'),
            onTap: () async {
              Navigator.pop(c);
              final x = items[k]![i];
              final r = await _ask('Allocate Amount', init: toD(x['orig'] ?? x['amount']), cur: x['cur']?.toString());
              if (r != null) setState(() => x.addAll(r));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Palette.of(c).neg),
            title: Text('Remove', style: TextStyle(color: Palette.of(c).neg)),
            onTap: () {
              Navigator.pop(c);
              setState(() => items[k]!.removeAt(i));
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final s = StoreScope.read(context);
    final incO = parseAmount(income.text) ?? 0;
    final icur = incomeCur ?? s.base;
    setState(() {
      errName = name.text.trim().isEmpty ? 'Please enter a plan name' : null;
      errIncome = incO > 0 ? null : 'Please enter salary amount';
    });
    if (errName != null || errIncome != null) return;
    final e = widget.existing;
    final rec = <String, dynamic>{
      if (e != null) 'id': e['id'],
      'name': name.text.trim(),
      'month': month,
      'income': round2(s.conv(incO, icur, s.base)),
      'incomeOrig': incO,
      'incomeCur': icur,
      for (final k in items.keys) k: items[k]!.map((x) => Map<String, dynamic>.from(x)).toList(),
    };
    final isNew = e == null;
    var budgets = false;
    if (isNew && items['expenses']!.isNotEmpty) {
      budgets = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Create Monthly Budgets?'),
              content: const Text('Do you want to create monthly budgets based on this salary plan?'),
              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes'))],
            ),
          ) ==
          true;
    }
    final id = s.savePlan(rec, createBudgets: budgets);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    if (isNew) nav.push(pageRoute(PlanDetailScreen(id: id)));
    toast(context, isNew ? 'Salary plan created successfully' : 'Plan updated');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final ic0 = incomeCur ?? s.base;
    final incO = parseAmount(income.text) ?? 0;
    final inc = round2(s.conv(incO, ic0, s.base));
    double sumK(String k) => items[k]!.fold(0.0, (a, x) => a + toD(x['amount']));
    final a = (exp: sumK('expenses'), loan: sumK('loans'), card: sumK('cards'), goal: sumK('goals'));
    final tot = a.exp + a.loan + a.card + a.goal, rem = inc - tot;
    String hv(double v) => hide ? '••••' : moneyB(s, v);
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${widget.existing != null ? 'Edit' : 'Create'} Monthly Plan'), Text('Build your plan in a few simple steps', style: TextStyle(color: p.muted, fontSize: 12.5))])),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton.icon(icon: const Icon(Icons.check_rounded), label: Text(widget.existing != null ? 'Save Plan' : 'Create Plan'), onPressed: _save),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        TextField(controller: name, decoration: InputDecoration(labelText: 'Plan name', hintText: 'e.g. February budget', errorText: errName, prefixIcon: const Icon(Icons.notes_rounded))),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonthsYm(month, -1)), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: Center(child: Text(_fML(month), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
          IconButton(onPressed: () => setState(() => month = addMonthsYm(month, 1)), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          ActionChip(
            label: Text('$ic0 ▾'),
            onPressed: () async {
              final x = await pickCurrency(context, ic0);
              if (x != null) setState(() => incomeCur = x);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: income,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => errIncome = null),
              decoration: InputDecoration(labelText: 'Monthly Income', hintText: 'Enter salary amount', errorText: errIncome),
            ),
          ),
        ]),
        if (ic0 != s.base && incO > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('≈ ${moneyB(s, inc)} at 1 $ic0 = ${s.rates.rateOf(ic0, s.base).toStringAsFixed(4)} ${s.base}', style: TextStyle(color: p.pos, fontSize: 12.5))),
        const SizedBox(height: 14),
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withOpacity(.2), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Remaining Amount', style: TextStyle(color: p.muted))),
              IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
            ]),
            Text(hv(rem), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: rem < 0 ? p.neg : p.pos)),
            Divider(height: 20, color: p.line),
            for (final x in [('Total Allocated', tot), ('Expenses', a.exp), ('Loan Payments', a.loan), ('Credit Card Payments', a.card), ('Saving Goals', a.goal)])
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(x.$1, style: TextStyle(color: p.muted))), Text(hv(x.$2), style: const TextStyle(fontWeight: FontWeight.w700))])),
          ]),
        ),
        for (final sc in _secs) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
            child: Row(children: [
              Expanded(child: Text(sc.$2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton.filledTonal(onPressed: () => _add(sc.$1), icon: const Icon(Icons.add_rounded)),
            ]),
          ),
          if (items[sc.$1]!.isEmpty)
            GlassCard(
              child: Column(children: [
                Icon(sc.$4, color: p.pos),
                const SizedBox(height: 6),
                Text(sc.$5, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
                TextButton(onPressed: () => _add(sc.$1), child: Text(sc.$6)),
              ]),
            )
          else
            for (var i = 0; i < items[sc.$1]!.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(builder: (_) {
                  final x = items[sc.$1]![i];
                  final l = _label(s, sc.$1, x);
                  return GlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(children: [
                      EmojiTile(l.$1, size: 42),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${l.$3}${_curNote(s, x)}', style: TextStyle(color: p.muted, fontSize: 12.5))])),
                      Text(moneyB(s, toD(x['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(onPressed: () => _itemMenu(sc.$1, i), icon: const Icon(Icons.more_vert_rounded)),
                    ]),
                  );
                }),
              ),
        ],
      ]),
    );
  }
}
