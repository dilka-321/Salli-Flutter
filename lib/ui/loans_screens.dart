import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/loans.dart';
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

const _blue = Color(0xFF5B8DEF);

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});
  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  String tab = 'unpaid', f = 'all';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    var L = s.loans.where((l) => tab == 'unpaid' ? s.loanRemain(l) > 0 : s.loanRemain(l) <= 0).toList();
    if (f != 'all') L = L.where((l) => l['type'] == f).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(pageRoute(const LoanFormScreen())), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'unpaid', label: Text('Unpaid Loans'), icon: Icon(Icons.receipt_long_rounded)),
            ButtonSegment(value: 'paid', label: Text('Paid Loans'), icon: Icon(Icons.check_rounded)),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          for (final e in const {'all': 'All', 'bank': 'Bank Loan', 'personal': 'Personal Loan'}.entries) ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
        ]),
        if (L.isEmpty) EmptyNote(tab == 'unpaid' ? 'No unpaid loans found. Add a new loan to get started.' : 'No paid loans yet.', icon: Icons.account_balance_rounded),
        for (final l in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final r = s.loanRemain(l), tot = s.loanTotal(l), c = s.lcur(l);
              final od = s.loanOverdue(l);
              final bank = l['type'] == 'bank';
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(LoanDetailScreen(id: '${l['id']}'))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: p.neg.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.account_balance_rounded, color: p.neg)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${l['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${'${l['lender'] ?? ''}'.isNotEmpty ? '${l['lender']} · ' : ''}$c · ${plainNum(toD(l['rate']))}%${s.hasTenure(l) ? ' · ${plainNum(toD(l['months']))} months' : ''}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ]),
                    ),
                    if (od != null) ...[Badge2('OVERDUE', color: p.neg), const SizedBox(width: 4)],
                    Badge2(bank ? 'BANK' : 'PERSONAL', color: bank ? _blue : p.warn),
                  ]),
                  const SizedBox(height: 10),
                  ProgressBar(tot > 0 ? 1 - r / tot : 1, color: _blue),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text('Remaining', style: TextStyle(color: p.muted, fontSize: 13))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(r, c), style: TextStyle(color: p.neg, fontWeight: FontWeight.w800)),
                      if (c != s.base) Text('≈ ${moneyB(s, s.loanRemainB(l))}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                    ]),
                  ]),
                  if (r > 0 && s.hasTenure(l)) Row(children: [Expanded(child: Text('Monthly EMI', style: TextStyle(color: p.muted, fontSize: 12))), Text(money(s.emiOf(l), c), style: TextStyle(color: p.muted, fontSize: 12))]),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final l = s.loan(id);
    if (l == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This loan was deleted.'));
    final c = s.lcur(l);
    String M(num x) => money(x, c);
    final r = s.loanRemain(l), tot = s.loanTotal(l), paid = s.loanPaid(l), e = s.emiOf(l), hasT = s.hasTenure(l);
    final rows = s.loanSchedule(l);
    final pays = s.loanPayments(l);
    final nPaid = math.min(pays.length, rows.length);
    final od = s.loanOverdue(l);
    final t = today();
    final rates = l['rates'] is Map ? (l['rates'] as Map) : const {};
    final info = <(String, String)>[
      ('Lender', '${l['lender'] ?? ''}'.isEmpty ? '—' : '${l['lender']}'),
      ('Currency', '$c — ${kCurrencyMap[c]?.name ?? ''}'),
      for (final k in rates.keys)
        ('Agreed rate', s.loanRateInv(l, '$k') ? '1 $k = ${(1 / toD(rates[k])).toStringAsFixed(4)} $c' : '1 $c = ${toD(rates[k]).toStringAsFixed(4)} $k'),
      ('Original Amount', M(toD(l['principal']))),
      ('Interest Rate', '${plainNum(toD(l['rate']))}% per year'),
      if (hasT) ...[
        ('Tenure', '${plainNum(toD(l['months']))} months'),
        ('Total Payable', M(tot)),
        ('Total Interest', M(tot - toD(l['principal']))),
        ('First Instalment', fmtDate('${l['start']}')),
        ('Instalments Paid', '$nPaid of ${plainNum(toD(l['months']))}'),
      ] else
        ('Start date', fmtDate('${l['start']}')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${l['name']}'), actions: [
        Center(child: Badge2(l['type'] == 'bank' ? 'BANK' : 'PERSONAL', color: r > 0 ? p.pos : p.muted)),
        moreMenu([
          ('Edit loan', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(LoanFormScreen(existing: l))), false),
          (
            'Delete loan',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete loan?', 'The loan, the loan received transaction and all its repayment transactions are removed, and your account balances are updated.')) {
                s.removeLoan(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Loan deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      bottomNavigationBar: r <= 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: FilledButton.icon(
                  style: od != null ? FilledButton.styleFrom(backgroundColor: p.neg, foregroundColor: Colors.white) : null,
                  icon: const Icon(Icons.credit_card_rounded),
                  label: Text(od != null ? 'PAY NOW - OVERDUE' : 'Pay now'),
                  onPressed: () => showLoanPay(context, id),
                ),
              ),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.16), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${l['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              Badge2('● ${od != null ? 'OVERDUE' : r > 0 ? 'ACTIVE' : 'PAID'}', color: od != null ? p.neg : r > 0 ? p.pos : _blue),
            ]),
            if (od != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Instalment #${od.k} was due ${fmtDate(od.d)} · ${od.days} day${od.days > 1 ? 's' : ''} overdue', style: TextStyle(color: p.neg, fontSize: 12.5))),
            const SizedBox(height: 8),
            Text('Remaining Balance', style: TextStyle(color: p.muted)),
            Text(M(r), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.pos)),
            if (c != s.base) Text('≈ ${moneyB(s, s.loanRemainB(l))}', style: TextStyle(color: p.muted)),
            const SizedBox(height: 8),
            ProgressBar(tot > 0 ? paid / tot : 0, color: _blue),
            const SizedBox(height: 6),
            Text('${(tot > 0 ? paid / tot * 100 : 0).round()}% repaid', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          InfoTile(icon: Icons.payments_outlined, label: 'Amount Paid', value: M(paid), color: p.pos, valueColor: p.pos),
          InfoTile(icon: Icons.trending_up_rounded, label: hasT ? 'Monthly EMI' : 'Tenure', value: hasT ? M(e) : 'Not set', color: _blue),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.info_outline_rounded, size: 20), SizedBox(width: 8), Text('Loan Information', style: TextStyle(fontWeight: FontWeight.w800))]),
            for (final x in info) kvRow(p, x.$1, x.$2),
          ]),
        ),
        if (r > 0 && nPaid < rows.length) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Upcoming schedule', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final x in rows.skip(nPaid).take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('#${x.k} · ${fmtDate(x.d)}', style: TextStyle(color: x.d.compareTo(t) < 0 ? p.neg : null)),
                          if (x.d.compareTo(t) < 0) ...[const SizedBox(width: 6), Badge2('OVERDUE', color: p.neg)],
                        ]),
                        Text('Interest ${M(x.it)} · Principal ${M(x.pr)}', style: TextStyle(color: p.muted, fontSize: 12)),
                      ]),
                    ),
                    Text(M(e), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
          ),
        ],
        const SectionTitle('Payment History'),
        if (pays.isEmpty)
          GlassCard(child: Text('No payments yet.', style: TextStyle(color: p.muted)))
        else
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Column(children: [
              for (final x in pays.reversed)
                Row(children: [
                  Expanded(
                    child: kvRow(
                      p,
                      fmtDate('${x['date']}'),
                      M(toD(x['amount'])),
                      color: p.pos,
                      sub: [
                        if ('${x['note'] ?? ''}'.isNotEmpty) '${x['note']}',
                        if (x['payCur'] != null && x['payCur'] != c) 'Paid ${money(toD(x['paid']), '${x['payCur']}')} at 1 ${x['payCur']} = ${toD(x['rate']).toStringAsFixed(4)} $c',
                        if (toD(x['fee']) > 0) '+ fee ${money(toD(x['fee']), '${x['payCur'] ?? c}')}',
                      ].join('\n'),
                    ),
                  ),
                  moreMenu([
                    ('Edit payment', Icons.edit_outlined, () => showLoanPayEdit(context, id, '${x['id']}'), false),
                    (
                      'Delete payment',
                      Icons.delete_outline,
                      () async {
                        if (await confirmDialog(context, 'Delete payment?', 'This payment, its transaction and any bank fee are removed. The loan balance goes back up.')) {
                          s.deleteLoanPayment(id, '${x['id']}');
                          if (context.mounted) toast(context, 'Payment deleted');
                        }
                      },
                      true
                    ),
                  ]),
                ]),
            ]),
          ),
      ]),
    );
  }
}

/// Shared "settlement" sheet for loans (pay) and lendings (receive): any currency, converted into the owed currency.
Future<({double v, String cur, double fee, String accId, String date, String note})?> showSettleSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String owedCur,
  required double Function(double v, String from, String to) convert,
  required String initCur,
  required String initAmt,
  required String? accId,
  String note = '',
  String? hint,
  bool fee = false,
  String button = 'Make Payment',
  String accLabel = 'PAY FROM WALLET:',
  bool lockCurrency = false,
}) {
  final amt = TextEditingController(text: initAmt);
  final feeCtl = TextEditingController();
  final noteCtl = TextEditingController(text: note);
  var cur = initCur;
  var acc = accId;
  var date = today();
  String? err;
  return showModalBottomSheet<({double v, String cur, double fee, String accId, String date, String note})>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final s = StoreScope.of(c);
      final p = Palette.of(c);
      final v = parseAmount(amt.text) ?? 0;
      final ac = acc == null ? null : s.accCur(acc);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              Row(children: [
                Text('AMOUNT', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                const Spacer(),
                ActionChip(
                  label: Text('${currencySymbol(cur)} $cur${lockCurrency ? '' : ' ▾'}'),
                  onPressed: lockCurrency
                      ? null
                      : () async {
                          final x = await pickCurrency(c, cur);
                          if (x == null) return;
                          set(() {
                            final vv = parseAmount(amt.text) ?? 0;
                            if (vv > 0) amt.text = plainNum(round2(convert(vv, cur, x)));
                            cur = x;
                          });
                        },
                ),
              ]),
              AmountBox(controller: amt, currency: cur, label: '', onChanged: (_) => set(() => err = null)),
              if (cur != owedCur && v > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '= ${money(convert(v, cur, owedCur), owedCur)} off the balance · ${s.fxStrong(cur, owedCur) ? '1 $cur = ${convert(1, cur, owedCur).toStringAsFixed(4)} $owedCur' : '1 $owedCur = ${convert(1, owedCur, cur).toStringAsFixed(4)} $cur'}',
                    style: TextStyle(color: p.pos, fontSize: 12.5),
                  ),
                ),
              if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: TextStyle(color: p.muted, fontSize: 12.5))),
              if (fee) ...[
                const SizedBox(height: 12),
                TextField(controller: feeCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Bank fee (optional, $cur)', hintText: '0.00')),
              ],
              const SizedBox(height: 14),
              Text(accLabel, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              AccountChips(
                value: acc,
                walletsOnly: true,
                onChanged: (x) => set(() {
                  acc = x;
                  if (x == null || lockCurrency) return;
                  final a2 = s.accCur(x);
                  if (a2 != cur) {
                    final vv = parseAmount(amt.text) ?? 0;
                    if (vv > 0) amt.text = plainNum(round2(convert(vv, cur, a2)));
                    cur = a2;
                  }
                }),
              ),
              if (ac != null && ac != cur && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${money(convert(v, cur, ac), ac)} will move in ${s.accName(acc)}.', style: TextStyle(color: p.muted, fontSize: 12.5))),
              const SizedBox(height: 12),
              DateButton(value: date, label: 'Date', onChanged: (x) => set(() => date = x)),
              const SizedBox(height: 10),
              TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'Note')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final vv = parseAmount(amt.text) ?? 0;
                  if (vv <= 0) return set(() => err = 'Enter an amount above zero.');
                  if (acc == null) return set(() => err = 'Choose a wallet.');
                  HapticFeedback.lightImpact();
                  Navigator.pop(c, (v: vv, cur: cur, fee: parseAmount(feeCtl.text) ?? 0.0, accId: acc!, date: date, note: noteCtl.text));
                },
                child: Text(button),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

Future<void> showLoanPay(BuildContext context, String id) async {
  final s = StoreScope.read(context);
  final l = s.loan(id);
  if (l == null) return;
  final c = s.lcur(l);
  final due = s.hasTenure(l) ? math.min(s.emiOf(l), s.loanRemain(l)) : s.loanRemain(l);
  final r = await showSettleSheet(
    context,
    title: 'Pay now',
    subtitle: 'Record a payment for this loan · balance ${money(s.loanRemain(l), c)}',
    owedCur: c,
    convert: (v, a, b) => s.lconv(l, v, a, b),
    initCur: c,
    initAmt: due.toStringAsFixed(2),
    accId: s.defaultAccId,
    note: 'Loan payment - ${l['name']}',
    hint: s.hasTenure(l) ? 'Monthly instalment ${money(s.emiOf(l), c)}' : 'Remaining balance ${money(s.loanRemain(l), c)}',
    fee: true,
  );
  if (r == null) return;
  s.payLoan(id, v: r.v, cur: r.cur, fee: r.fee, accId: r.accId, date: r.date, note: r.note);
  if (context.mounted) toast(context, s.loanRemain(l) <= 0 ? 'Loan fully paid' : 'Payment recorded');
}

Future<void> showLoanPayEdit(BuildContext context, String lid, String pid) async {
  final s = StoreScope.read(context);
  final l = s.loan(lid);
  final pm = l == null ? null : s.loanPayments(l).where((y) => y['id'] == pid).firstOrNull;
  if (l == null || pm == null) return;
  final c = s.lcur(l), pc = '${pm['payCur'] ?? c}';
  final tx = s.txns.where((t) => t['id'] == pm['txId']).firstOrNull;
  final amt = TextEditingController(text: plainNum(toD(pm['paid'] ?? pm['amount'])));
  final feeCtl = TextEditingController(text: toD(pm['fee']) > 0 ? plainNum(toD(pm['fee'])) : '');
  final noteCtl = TextEditingController(text: '${pm['note'] ?? ''}');
  String? acc = tx?['accId']?.toString() ?? pm['accId']?.toString() ?? s.defaultAccId;
  var date = '${pm['date']}';
  String? err;
  final rate = pc == c ? 1.0 : (toD(pm['rate']) != 0 ? toD(pm['rate']) : s.lconv(l, 1, pc, c));
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sh) => StatefulBuilder(builder: (sh, set) {
      final p = Palette.of(sh);
      final v = parseAmount(amt.text) ?? 0;
      final ac = acc == null ? null : s.accCur(acc);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sh).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Edit payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${l['name']} · ${fmtDate('${pm['date']}')}', style: TextStyle(color: p.muted)),
              const SizedBox(height: 12),
              AmountBox(controller: amt, currency: pc, label: 'Amount ($pc)', onChanged: (_) => set(() => err = null)),
              if (pc != c && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('= ${money(round2(v * rate), c)} off the balance · 1 $pc = ${rate.toStringAsFixed(4)} $c', style: TextStyle(color: p.pos, fontSize: 12.5))),
              const SizedBox(height: 12),
              TextField(controller: feeCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Bank fee (optional, $pc)', hintText: '0.00')),
              const SizedBox(height: 12),
              Text('PAID FROM WALLET:', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              AccountChips(value: acc, walletsOnly: true, onChanged: (x) => set(() => acc = x)),
              if (ac != null && ac != pc && v > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${money(s.lconv(l, v, pc, ac), ac)} will be taken from ${s.accName(acc)}.', style: TextStyle(color: p.muted, fontSize: 12.5))),
              const SizedBox(height: 12),
              DateButton(value: date, label: 'Payment date', onChanged: (x) => set(() => date = x)),
              const SizedBox(height: 10),
              TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'Note')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final vv = parseAmount(amt.text) ?? 0;
                  if (vv <= 0) return set(() => err = 'Enter an amount above zero.');
                  if (acc == null) return set(() => err = 'Choose a wallet.');
                  s.editLoanPayment(lid, pid, v: vv, fee: parseAmount(feeCtl.text) ?? 0, accId: acc!, date: date, note: noteCtl.text);
                  Navigator.pop(sh);
                  toast(context, 'Payment updated');
                },
                child: const Text('Save changes'),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

/// Add / edit loan, with optional agreed exchange rates per currency.
class LoanFormScreen extends StatefulWidget {
  const LoanFormScreen({super.key, this.existing});
  final J? existing;
  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  String type = 'bank';
  final name = TextEditingController();
  final lender = TextEditingController();
  final principal = TextEditingController();
  final rate = TextEditingController();
  final months = TextEditingController(text: '12');
  late String currency;
  String start = addMonths(today(), 1);
  String? accId;
  final rateCtl = <String, TextEditingController>{};
  final rateInv = <String, bool>{};
  String? err;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final l = widget.existing;
    currency = s.base;
    if (l != null) {
      type = '${l['type'] ?? 'bank'}';
      name.text = '${l['name'] ?? ''}';
      lender.text = '${l['lender'] ?? ''}';
      currency = s.lcur(l);
      principal.text = plainNum(toD(l['principal']));
      rate.text = toD(l['rate']) != 0 ? plainNum(toD(l['rate'])) : '';
      months.text = toD(l['months']) > 0 ? plainNum(toD(l['months'])) : '';
      start = '${l['start'] ?? today()}';
      final rs = l['rates'] is Map ? l['rates'] as Map : const {};
      for (final k in rs.keys) {
        final inv = s.loanRateInv(l, '$k');
        rateInv['$k'] = inv;
        final v = toD(rs[k]);
        rateCtl['$k'] = TextEditingController(text: v == 0 ? '' : (inv ? 1 / v : v).toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, lender, principal, rate, months, ...rateCtl.values]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _locked => widget.existing != null && StoreScope.read(context).loanPayments(widget.existing!).isNotEmpty;
  bool _inv(AppStore s, String c) => rateInv[c] ?? !s.fxStrong(currency, c);
  TextEditingController _ctl(String c) => rateCtl.putIfAbsent(c, () => TextEditingController());

  Map<String, double> _rates(AppStore s) {
    final o = <String, double>{};
    rateCtl.forEach((c, ctl) {
      final v = parseAmount(ctl.text) ?? 0;
      if (v > 0 && c != currency) o[c] = _inv(s, c) ? 1 / v : v;
    });
    return o;
  }

  void _save() {
    final s = StoreScope.read(context);
    final P = parseAmount(principal.text) ?? 0, r = parseAmount(rate.text) ?? 0, m = int.tryParse(months.text.trim()) ?? 0;
    String? e;
    if (name.text.trim().isEmpty) {
      e = 'Enter a loan name.';
    } else if (P <= 0) {
      e = 'Enter the loan amount.';
    } else if (r > 0 && m <= 0) {
      e = 'Enter the tenure in months to calculate interest.';
    }
    if (e != null) return setState(() => err = e);
    final rates = _rates(s);
    final dir = <String, bool>{for (final c in rates.keys) c: _inv(s, c)};
    s.saveLoan(
      id: widget.existing?['id']?.toString(),
      name: name.text.trim(),
      type: type,
      lender: lender.text,
      currency: currency,
      principal: P,
      rate: r,
      months: m,
      start: start,
      rates: rates,
      rateDir: dir,
      accId: accId,
    );
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    toast(context, widget.existing != null ? 'Loan updated' : 'Loan added');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final P = parseAmount(principal.text) ?? 0, r = parseAmount(rate.text) ?? 0, m = int.tryParse(months.text.trim()) ?? 0;
    final emi = P > 0 && m > 0 ? s.emiOf({'principal': P, 'rate': r, 'months': m}) : 0.0;
    final curs = <String>{s.base, ...s.accounts.map((a) => '${a['currency']}')}.where((c) => c.isNotEmpty && c != currency).toList();
    final tmp = <String, dynamic>{'currency': currency, 'rates': _rates(s)};
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Loan' : 'Add Loan')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton(onPressed: _save, child: const Text('Save')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'bank', label: Text('Bank Loan')), ButtonSegment(value: 'personal', label: Text('Personal Loan'))],
          selected: {type},
          onSelectionChanged: (v) => setState(() {
            type = v.first;
            if (type == 'personal' && months.text == '12' && r == 0) months.text = '';
          }),
        ),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Loan name', hintText: 'e.g. Housing loan')),
        const SizedBox(height: 12),
        TextField(controller: lender, decoration: InputDecoration(labelText: type == 'bank' ? 'Bank / Lender' : 'Borrowed from')),
        const SizedBox(height: 12),
        FieldRow(
          icon: _locked ? Icons.lock_outline_rounded : Icons.currency_exchange_rounded,
          label: _locked ? 'Loan currency · can’t change after payments are recorded' : 'Loan currency',
          value: '$currency — ${kCurrencyMap[currency]?.name ?? ''}',
          onTap: _locked
              ? null
              : () async {
                  final x = await pickCurrency(context, currency);
                  if (x != null) setState(() => currency = x);
                },
        ),
        Row(children: [
          Expanded(child: TextField(controller: principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Loan amount (${currencySymbol(currency)})'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Interest rate (% / year)', hintText: '0'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: months, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Tenure (months)${r > 0 ? '' : ' · optional'}', hintText: r > 0 ? 'e.g. 24' : 'Not set'))),
          const SizedBox(width: 10),
          Expanded(child: DateButton(value: start, label: m > 0 ? 'First' : 'Start', onChanged: (v) => setState(() => start = v))),
        ]),
        if (emi > 0) ...[
          const SizedBox(height: 12),
          GlassCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: kvRow(p, 'Monthly instalment', money(emi, currency), color: p.pos)),
        ],
        if (curs.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Agreed exchange rates (optional)', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('The rate agreed for this loan. Payments and the liability use it instead of the app rate — only for this loan.', style: TextStyle(color: p.muted, fontSize: 12.5)),
              for (final c in curs)
                Builder(builder: (_) {
                  final inv = _inv(s, c);
                  final A = inv ? c : currency, B = inv ? currency : c;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(children: [
                      const Text('1 '),
                      ActionChip(
                        label: Text('$A ⇄'),
                        onPressed: () => setState(() {
                          final v = parseAmount(_ctl(c).text) ?? 0;
                          rateInv[c] = !inv;
                          if (v > 0) _ctl(c).text = (1 / v).toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                        }),
                      ),
                      const Text(' = '),
                      Expanded(
                        child: TextField(
                          controller: _ctl(c),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() => rateInv[c] = inv),
                          decoration: InputDecoration(hintText: s.rates.rateOf(A, B).toStringAsFixed(4), isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(B, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  );
                }),
              if (P > 0)
                for (final c in curs.where((c) => c == s.base || (tmp['rates'] as Map)[c] != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '≈ ${money(s.lconv(tmp, P, currency, c), c)} at ${s.fxStrong(currency, c) ? '1 $currency = ${s.lconv(tmp, 1, currency, c).toStringAsFixed(4)} $c' : '1 $c = ${s.lconv(tmp, 1, c, currency).toStringAsFixed(4)} $currency'}${(tmp['rates'] as Map)[c] != null ? ' (agreed rate)' : ''}',
                      style: TextStyle(color: p.pos, fontSize: 12.5),
                    ),
                  ),
            ]),
          ),
        ],
        if (widget.existing == null) ...[
          const SectionTitle('Money received into (optional)'),
          AccountChips(value: accId, allowNone: true, onChanged: (v) => setState(() => accId = v)),
          const SizedBox(height: 6),
          Text(
            'Selecting an account records the loan amount as money in${accId != null && s.accCur(accId) != currency && P > 0 ? ' (${money(s.lconv(tmp, P, currency, s.accCur(accId)), s.accCur(accId))})' : ''}.',
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
        ],
        if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: TextStyle(color: p.neg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Loan Analyzer — EMI, interest, extra payments, yearly breakdown.
class LoanAnalyzerScreen extends StatefulWidget {
  const LoanAnalyzerScreen({super.key});
  @override
  State<LoanAnalyzerScreen> createState() => _LoanAnalyzerScreenState();
}

class _LoanAnalyzerScreenState extends State<LoanAnalyzerScreen> {
  final c = {'P': TextEditingController(text: '1000000'), 'r': TextEditingController(text: '14'), 'n': TextEditingController(text: '60'), 'inc': TextEditingController(), 'extra': TextEditingController()};

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  String _compact(double v) {
    final a = v.abs();
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    double g(String k) => parseAmount(c[k]!.text) ?? 0;
    final P = g('P'), r = g('r'), n = g('n').toInt(), inc = g('inc'), ex = g('extra');
    Widget f(String k, String l, {String? hint}) => TextField(controller: c[k], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l, hintText: hint));
    final out = <Widget>[];
    if (P > 0 && n > 0) {
      final e = s.emiOf({'principal': P, 'rate': r, 'months': n});
      final tot = e * n, it = tot - P;
      var bal = P, m = 0, int2 = 0.0;
      final rr = r / 1200;
      while (bal > 0.01 && m < 1200) {
        final x = bal * rr;
        int2 += x;
        bal = bal + x - (e + ex);
        m++;
      }
      final yrs = <(int, double, double, double)>[];
      bal = P;
      for (var y = 1; y <= (n / 12).ceil(); y++) {
        var ip = 0.0, pp = 0.0;
        for (var k = 0; k < 12 && (y - 1) * 12 + k < n; k++) {
          final x = bal * rr;
          ip += x;
          pp += e - x;
          bal = math.max(0.0, bal - (e - x));
        }
        yrs.add((y, ip, pp, bal));
      }
      final ratio = inc > 0 ? e / inc : null;
      out.addAll([
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.16), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monthly instalment (EMI)', style: TextStyle(color: p.muted)),
            Text(moneyB(s, e), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.pos)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total interest', style: TextStyle(color: p.muted, fontSize: 12)), Text(moneyB(s, it), style: TextStyle(color: p.neg, fontWeight: FontWeight.w800))])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total payable', style: TextStyle(color: p.muted, fontSize: 12)), Text(moneyB(s, tot), style: const TextStyle(fontWeight: FontWeight.w800))])),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(height: 12, child: Row(children: [Expanded(flex: math.max(1, (P / tot * 1000).round()), child: Container(color: p.accent)), Expanded(flex: math.max(1, (it / tot * 1000).round()), child: Container(color: p.neg))])),
            ),
            const SizedBox(height: 6),
            Text('● Principal ${(P / tot * 100).round()}%   ● Interest ${(it / tot * 100).round()}%', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
        if (ratio != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Row(children: [
              Icon(Icons.shield_outlined, color: ratio <= .3 ? p.pos : ratio <= .45 ? p.warn : p.neg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EMI is ${(ratio * 100).round()}% of your income', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(ratio <= .3 ? 'Comfortable — under the common 30% guideline.' : ratio <= .45 ? 'Manageable, but leaves less room for savings.' : 'High — consider a longer tenure or a smaller loan.', style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
            ]),
          ),
        ],
        if (ex > 0) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Paying ${moneyB(s, ex)} extra each month', style: const TextStyle(fontWeight: FontWeight.w800)),
              kvRow(p, 'Paid off in', '$m months (${n - m} sooner)'),
              kvRow(p, 'Interest saved', moneyB(s, math.max(0.0, it - int2)), color: p.pos),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yearly breakdown', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {0: FlexColumnWidth(.6)},
              children: [
                TableRow(children: [for (final h in ['Year', 'Principal', 'Interest', 'Balance']) Text(h, textAlign: h == 'Year' ? TextAlign.left : TextAlign.right, style: TextStyle(color: p.muted, fontSize: 12))]),
                for (final y in yrs)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text('${y.$1}', style: const TextStyle(fontSize: 12.5))),
                    Text(_compact(y.$3), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5)),
                    Text(_compact(y.$2), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: p.neg)),
                    Text(_compact(y.$4), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5)),
                  ]),
              ],
            ),
          ]),
        ),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Analyzer')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(children: [
            f('P', 'Loan amount'),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: f('r', 'Interest rate (% / year)')), const SizedBox(width: 10), Expanded(child: f('n', 'Tenure (months)'))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: f('inc', 'Monthly income (optional)')), const SizedBox(width: 10), Expanded(child: f('extra', 'Extra monthly payment', hint: '0'))]),
          ]),
        ),
        const SizedBox(height: 12),
        ...out,
      ]),
    );
  }
}
