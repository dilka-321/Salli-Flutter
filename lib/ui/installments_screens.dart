import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

String _short(String d) => fmtDate(d).replaceAll(RegExp(r', \d{4}$'), '');
String _left(String t, String d) => d.compareTo(t) < 0 ? '${diffDays(d, t)} days overdue' : '${diffDays(t, d)} days left';

Color _statusColor(Palette p, String c) => c == 'green' ? p.pos : c == 'blue' ? p.accent : p.warn;

/// Installments: Overview · Active · Completed (like the web app).
class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});
  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  String tab = 'overview';
  String q = '';

  void _new() => Navigator.of(context).push(pageRoute(const InstWizardScreen()));

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final act = s.installments.where((x) => s.instRemain(x) > 0).toList();
    final done = s.installments.where((x) => s.instRemain(x) <= 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Installments')),
      floatingActionButton: FloatingActionButton(onPressed: _new, tooltip: 'Add installment', child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'overview', label: Text('Overview'), icon: Icon(Icons.dashboard_outlined)),
            ButtonSegment(value: 'active', label: Text('Active')),
            ButtonSegment(value: 'completed', label: Text('Completed'), icon: Icon(Icons.check_rounded)),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 14),
        if (tab == 'overview') ..._overview(context, s, act) else ..._list(context, s, tab == 'active' ? act : done),
      ]),
    );
  }

  List<Widget> _overview(BuildContext context, AppStore s, List<J> act) {
    final p = Palette.of(context);
    if (s.installments.isEmpty) {
      return [
        const EmptyNote('No installments yet\nTrack anything you pay in installments — phones, appliances, education, insurance and more.', icon: Icons.receipt_long_rounded),
        Center(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add installment'), onPressed: _new)),
      ];
    }
    final out = act.fold(0.0, (a, x) => a + s.instRemain(x));
    final paid = s.installments.fold(0.0, (a, x) => a + s.instPaidAmt(x));
    final tot = out + paid;
    final pc = tot > 0 ? paid / tot : 0.0;
    final t = today();
    final nexts = <(J, String)>[];
    for (final x in act) {
      final d = s.instNext(x);
      if (d != null) nexts.add((x, d));
    }
    nexts.sort((a, b) => a.$2.compareTo(b.$2));
    final up = nexts.where((o) => o.$2.compareTo(t) >= 0 && diffDays(t, o.$2) <= 7).toList();
    final od = nexts.where((o) => o.$2.compareTo(t) < 0).toList();
    final in30 = nexts.where((o) => o.$2.compareTo(t) >= 0 && diffDays(t, o.$2) <= 30).toList();
    double sumOf(Iterable<(J, String)> l) => l.fold(0.0, (a, o) => a + toD(o.$1['amount']));
    double band(int a, int z) => sumOf(in30.where((o) {
          final dd = diffDays(t, o.$2);
          return dd >= a && dd <= z;
        }));
    Widget stat(IconData i, Color c, int n, String l, double v) => GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: c.withOpacity(.15), shape: BoxShape.circle), child: Icon(i, color: c, size: 18)),
            const SizedBox(height: 8),
            Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(l, style: TextStyle(color: p.muted, fontSize: 12)),
            FittedBox(child: Text(moneyB(s, v), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        );
    return [
      GlassCard(
        gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withOpacity(.2), p.card), p.card]),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Outstanding', style: TextStyle(color: p.muted)),
              Text(moneyB(s, out), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Paid so far', style: TextStyle(color: p.muted, fontSize: 12)), Text(moneyB(s, paid), style: const TextStyle(fontWeight: FontWeight.w700))])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Overall Progress', style: TextStyle(color: p.muted, fontSize: 12)), Text('${(pc * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700))])),
              ]),
            ]),
          ),
          Ring(pc, center: '${(pc * 100).round()}%', caption: 'Paid'),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: stat(Icons.event_rounded, p.pos, up.length, 'Upcoming', sumOf(up))),
        const SizedBox(width: 8),
        Expanded(child: stat(Icons.info_outline_rounded, p.warn, od.length, 'Overdue', sumOf(od))),
        const SizedBox(width: 8),
        Expanded(child: stat(Icons.account_balance_wallet_outlined, p.accent, act.length, 'Active Plans', out)),
      ]),
      if (nexts.isNotEmpty) ...[
        const SizedBox(height: 12),
        GlassCard(
          onTap: () => Navigator.of(context).push(pageRoute(InstDetailScreen(id: '${nexts[0].$1['id']}'))),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: p.pos.withOpacity(.15), shape: BoxShape.circle), child: Icon(Icons.payments_outlined, color: p.pos)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Next Payment', style: TextStyle(color: p.muted, fontSize: 12.5)),
                Text('${nexts[0].$1['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_left(t, nexts[0].$2), style: TextStyle(color: nexts[0].$2.compareTo(t) < 0 ? p.neg : p.pos, fontSize: 12.5)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(moneyB(s, toD(nexts[0].$1['amount'])), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(_short(nexts[0].$2), style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('UPCOMING COMMITMENT', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
          Text('Next 30 days · ${in30.length} payments due', style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(moneyB(s, sumOf(in30)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Total amount due', style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(children: [
            for (final b in [('This Week', band(0, 7)), ('Next 7-14 Days', band(8, 14)), ('Next 15-30 Days', band(15, 30))])
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('● ${b.$1}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                  FittedBox(child: Text(b.$2 > 0 ? moneyB(s, b.$2) : '—', style: const TextStyle(fontWeight: FontWeight.w700))),
                ]),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Row(children: [
          Icon(od.isNotEmpty ? Icons.info_outline_rounded : Icons.celebration_rounded, color: od.isNotEmpty ? p.neg : p.accent, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(od.isNotEmpty ? '${od.length} overdue payment${od.length > 1 ? 's' : ''}' : 'Good job! You have no overdue payments', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(od.isNotEmpty ? 'Pay soon to avoid late fees.' : 'Stay on track and avoid late fees.', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    ];
  }

  List<Widget> _list(BuildContext context, AppStore s, List<J> L) {
    final p = Palette.of(context);
    final f = L.where((x) => q.isEmpty || '${x['title']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return [
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search installments'), onChanged: (v) => setState(() => q = v)),
      if (f.isEmpty) EmptyNote(tab == 'active' ? 'No active installments' : 'No completed installments yet\nPlans you finish paying off will show up here.', icon: Icons.check_circle_outline_rounded),
      for (final x in f)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Builder(builder: (_) {
            final st = s.instStatus(x);
            final n = s.instPaidCount(x), c = s.instCount(x);
            return GlassCard(
              onTap: () => Navigator.of(context).push(pageRoute(InstDetailScreen(id: '${x['id']}'))),
              child: Column(children: [
                Row(children: [
                  EmojiTile('${s.cat(x['catId'])?['icon'] ?? '🧾'}', tint: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      if ('${x['lender'] ?? ''}'.isNotEmpty) Text('${x['lender']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ]),
                  ),
                  Badge2(st.$1, color: _statusColor(p, st.$2)),
                ]),
                const SizedBox(height: 12),
                ProgressBar(c > 0 ? n / c : 0, color: p.accent),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text('$n of $c paid', style: TextStyle(color: p.muted, fontSize: 12.5))),
                  Text('${moneyB(s, s.instRemain(x))} left', style: TextStyle(color: p.muted, fontSize: 12.5)),
                ]),
              ]),
            );
          }),
        ),
    ];
  }
}

/// Installment plan details: remaining balance, schedule and payments.
class InstDetailScreen extends StatefulWidget {
  const InstDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<InstDetailScreen> createState() => _InstDetailScreenState();
}

class _InstDetailScreenState extends State<InstDetailScreen> {
  String tab = 'schedule';

  Future<void> _pay(J x) async {
    final s = StoreScope.read(context);
    final r = await showPaySheet(
      context,
      title: 'Make Payment',
      subtitle: 'Installment ${s.instPaidCount(x) + 1} of ${s.instCount(x)} · due ${fmtDate(s.instNext(x) ?? today())}',
      amount: toD(x['amount']),
      accId: s.acc(x['accId']?.toString()) != null ? '${x['accId']}' : s.defaultAccId,
      currencyLabel: s.base,
      walletsOnly: true,
    );
    if (r == null) return;
    s.payInst(id: widget.id, amount: r.amount, accId: r.accId, date: r.date);
    if (mounted) toast(context, s.instRemain(x) <= 0 ? 'Installment plan completed' : 'Payment recorded');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final x = s.inst(widget.id);
    if (x == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This installment plan was deleted.'));
    final st = s.instStatus(x);
    final n = s.instPaidCount(x), cnt = s.instCount(x);
    final nx = s.instNext(x);
    final t = today();
    final init = s.instInitial(x);
    final pays = s.instPayments(x);
    final amt = toD(x['amount']);
    return Scaffold(
      appBar: AppBar(title: const Text('Installments'), actions: [
        moreMenu([
          (
            'Delete plan',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete installment plan?', 'Recorded payment transactions stay.')) {
                s.deleteInst(widget.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Installment deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      bottomNavigationBar: nx == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: FilledButton.icon(icon: const Icon(Icons.credit_card_rounded), label: const Text('Make Payment'), onPressed: () => _pay(x)),
              ),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if ('${x['lender'] ?? ''}'.isNotEmpty) Text('${x['lender']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                ]),
              ),
              Badge2(st.$1, color: _statusColor(p, st.$2)),
            ]),
            const SizedBox(height: 12),
            Text('Remaining Balance', style: TextStyle(color: p.muted)),
            Text(moneyB(s, s.instRemain(x)), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ProgressBar(cnt > 0 ? n / cnt : 0, color: p.accent),
            const SizedBox(height: 6),
            Text('$n of $cnt installments paid${toD(x['advance']) > 0 ? ' · advance ${moneyB(s, toD(x['advance']))} paid' : ''}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            Divider(height: 24, color: p.line),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Next Payment', style: TextStyle(color: p.muted, fontSize: 12)), Text(nx != null ? moneyB(s, amt) : '—', style: const TextStyle(fontWeight: FontWeight.w800))])),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Next due', style: TextStyle(color: p.muted, fontSize: 12)),
                  Text(nx != null ? _short(nx) : '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (nx != null) Padding(padding: const EdgeInsets.only(top: 4), child: Badge2(_left(t, nx), color: nx.compareTo(t) < 0 ? p.neg : p.accent)),
                ]),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Paid', style: TextStyle(color: p.muted, fontSize: 12)), Text(moneyB(s, s.instPaidAmt(x)), style: TextStyle(fontWeight: FontWeight.w800, color: p.pos))])),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'schedule', label: Text('Schedule')), ButtonSegment(value: 'payments', label: Text('Payments'))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 6),
        if (tab == 'schedule')
          for (var i = 0; i < cnt; i++)
            Builder(builder: (_) {
              final d = addMonths('${x['start']}', i);
              final double? paidAmt = i < init ? amt : (i - init < pays.length ? toD(pays[i - init]['amount']) : null);
              final late = paidAmt == null && d.compareTo(t) < 0;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: p.pos.withOpacity(.15), child: Text('${i + 1}', style: TextStyle(color: p.pos, fontWeight: FontWeight.w800, fontSize: 13))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtDate(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (paidAmt != null) Text('Paid: ${moneyB(s, paidAmt)}', style: TextStyle(color: p.pos, fontSize: 12)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(moneyB(s, amt), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Badge2(paidAmt != null ? 'Paid' : late ? 'Overdue' : 'Due', color: paidAmt != null ? p.pos : late ? p.neg : p.muted),
                    ]),
                  ]),
                ),
              );
            })
        else if (pays.isEmpty)
          EmptyNote('No payments recorded in the app yet.${init > 0 ? ' $init installments were marked as paid when the plan was added.' : ''}')
        else
          for (final y in pays.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(children: [
                  Expanded(child: kvRow(p, fmtDate('${y['date']}'), moneyB(s, toD(y['amount'])), color: p.pos, sub: s.accName(y['accId']))),
                  moreMenu([
                    (
                      'Delete payment',
                      Icons.delete_outline,
                      () async {
                        if (await confirmDialog(context, 'Delete payment?', 'The payment and its transaction are removed.')) {
                          s.deleteInstPayment(widget.id, '${y['id']}');
                          if (context.mounted) toast(context, 'Payment deleted');
                        }
                      },
                      true
                    ),
                  ]),
                ]),
              ),
            ),
      ]),
    );
  }
}

/// New installment — 4-step wizard, same rules as the web app.
class InstWizardScreen extends StatefulWidget {
  const InstWizardScreen({super.key});
  @override
  State<InstWizardScreen> createState() => _InstWizardScreenState();
}

class _InstWizardScreenState extends State<InstWizardScreen> {
  int step = 1;
  final title = TextEditingController();
  final lender = TextEditingController();
  final total = TextEditingController();
  final advance = TextEditingController();
  final count = TextEditingController(text: '12');
  final amount = TextEditingController();
  final initialPaid = TextEditingController(text: '0');
  String? catId, advAcc, accId;
  String start = addMonths(today(), 1);
  int remindDays = 3;
  String? err;
  static const _steps = ['Basics', 'Amount & schedule', 'Already paid', 'Reminder & extras'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    accId ??= StoreScope.read(context).defaultAccId;
  }

  @override
  void dispose() {
    for (final c in [title, lender, total, advance, count, amount, initialPaid]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _adv => parseAmount(advance.text) ?? 0;
  double get _tot => parseAmount(total.text) ?? 0;
  int get _cnt => int.tryParse(count.text.trim()) ?? 0;
  double get _fin => (_tot - _adv) > 0 ? _tot - _adv : 0;
  double get _amt {
    final a = parseAmount(amount.text) ?? 0;
    return a > 0 ? a : (_fin > 0 && _cnt > 0 ? round2(_fin / _cnt) : 0);
  }

  void _back() {
    if (step > 1) {
      setState(() {
        step--;
        err = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _next() {
    String? e;
    if (step == 1 && title.text.trim().isEmpty) e = 'Enter a title.';
    if (step == 2) {
      if (!(_tot > 0)) {
        e = 'Enter the total amount.';
      } else if (_adv >= _tot) {
        e = 'The advance must be less than the total amount.';
      } else if (!(_cnt > 0)) {
        e = 'Enter the number of installments.';
      }
    }
    if (step == 3) {
      final ip = int.tryParse(initialPaid.text.trim()) ?? 0;
      if (ip < 0 || ip > _cnt) e = 'Paid installments must be between 0 and $_cnt.';
    }
    if (e != null) return setState(() => err = e);
    if (step < 4) {
      HapticFeedback.selectionClick();
      return setState(() {
        step++;
        err = null;
      });
    }
    final s = StoreScope.read(context);
    s.createInst(
      title: title.text.trim(),
      lender: lender.text,
      catId: catId,
      total: _tot,
      advance: _adv,
      advAcc: advAcc,
      count: _cnt,
      amount: parseAmount(amount.text),
      start: start,
      accId: accId,
      remindDays: remindDays,
      initialPaid: int.tryParse(initialPaid.text.trim()) ?? 0,
    );
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    toast(context, 'New Installment saved');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final end = _cnt > 0 ? addMonths(start, _cnt - 1) : start;
    final c = s.cat(catId);
    final ip = int.tryParse(initialPaid.text.trim()) ?? 0;
    final body = <Widget>[];
    if (step == 1) {
      body.addAll([
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Phone installment', prefixIcon: Icon(Icons.receipt_outlined))),
        const SizedBox(height: 12),
        TextField(controller: lender, decoration: const InputDecoration(labelText: 'Lender / Company', hintText: 'Who are you paying?', prefixIcon: Icon(Icons.storefront_outlined))),
        const SizedBox(height: 12),
        FieldRow(
          icon: Icons.category_outlined,
          label: 'Category',
          value: c == null ? 'Select category' : '${c['icon']} ${c['name']}',
          muted: c == null,
          onTap: () async {
            final x = await pickCategory(context, current: catId);
            if (x != null) setState(() => catId = x);
          },
        ),
      ]);
    } else if (step == 2) {
      body.addAll([
        TextField(controller: total, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => err = null), decoration: InputDecoration(labelText: 'Total amount (${s.base})')),
        const SizedBox(height: 12),
        TextField(controller: advance, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => err = null), decoration: const InputDecoration(labelText: 'Advance payment (optional)', hintText: '0.00')),
        if (_adv > 0) ...[
          const SizedBox(height: 10),
          GlassCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: kvRow(p, 'Amount to pay in installments', moneyB(s, _fin))),
          const SizedBox(height: 10),
          Text('Advance paid from (optional)', style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          AccountChips(value: advAcc, onChanged: (v) => setState(() => advAcc = advAcc == v ? null : v)),
          const SizedBox(height: 6),
          Text('Choose an account to record the advance as an expense, or leave it empty if it was already recorded.', style: TextStyle(color: p.muted, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: count, keyboardType: TextInputType.number, onChanged: (_) => setState(() => err = null), decoration: const InputDecoration(labelText: 'Number of installments'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Each installment', hintText: _amt > 0 ? plainNum(_amt) : ''))),
        ]),
        const SizedBox(height: 12),
        DateButton(value: start, label: 'First due date', onChanged: (v) => setState(() => start = v)),
        const SizedBox(height: 6),
        Text('Frequency: Monthly', style: TextStyle(color: p.muted)),
      ]);
    } else if (step == 3) {
      body.addAll([
        GlassCard(child: Text("Already paying this plan? Enter how many installments you've paid before today so the balance is right.", style: TextStyle(color: p.muted))),
        const SizedBox(height: 12),
        TextField(controller: initialPaid, keyboardType: TextInputType.number, onChanged: (_) => setState(() => err = null), decoration: const InputDecoration(labelText: 'Installments already paid')),
        const SizedBox(height: 12),
        GlassCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: kvRow(p, 'Remaining after that', moneyB(s, (_fin - ip * _amt) > 0 ? _fin - ip * _amt : 0))),
      ]);
    } else {
      body.addAll([
        Text('Pay from (pre-selected when paying)', style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        AccountChips(value: accId, onChanged: (v) => setState(() => accId = v)),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment reminder', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Remind me before each due date', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in const [(0, 'On due date'), (1, '1 day'), (3, '3 days'), (7, '7 days')]) ChoiceChip(label: Text(r.$2), selected: remindDays == r.$1, onSelected: (_) => setState(() => remindDays = r.$1)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('To pay in installments', style: TextStyle(color: p.muted, fontSize: 12)),
                Text(moneyB(s, _fin), style: const TextStyle(fontWeight: FontWeight.w800)),
                if (_adv > 0) Text('after ${moneyB(s, _adv)} advance', style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Expected completion', style: TextStyle(color: p.muted, fontSize: 12)),
              Text(fmtDate(end), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ]);
    }
    return PopScope(
      canPop: step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('New Installment'), Text('Step $step of 4', style: TextStyle(color: p.muted, fontSize: 12.5))]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              if (step > 1) ...[Expanded(child: OutlinedButton(onPressed: _back, child: const Text('Back'))), const SizedBox(width: 12)],
              Expanded(child: FilledButton(onPressed: _next, child: Text(step < 4 ? 'Next' : 'Save'))),
            ]),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
          Row(children: [
            for (var i = 1; i <= 4; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(color: i <= step ? p.accent : p.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          Text(_steps[step - 1], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Column(key: ValueKey(step), crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: TextStyle(color: p.neg, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}
