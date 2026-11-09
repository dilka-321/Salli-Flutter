import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/loans.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'loans_screens.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

class LendingsScreen extends StatefulWidget {
  const LendingsScreen({super.key});
  @override
  State<LendingsScreen> createState() => _LendingsScreenState();
}

class _LendingsScreenState extends State<LendingsScreen> {
  String tab = 'out';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.lendings.where((x) => tab == 'out' ? s.lendRemain(x) > 0 : s.lendRemain(x) <= 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Lendings')),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(pageRoute(const LendingFormScreen())), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'out', label: Text('Outstanding'), icon: Icon(Icons.north_east_rounded)),
            ButtonSegment(value: 'rec', label: Text('Received'), icon: Icon(Icons.check_rounded)),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        if (L.isEmpty) EmptyNote(tab == 'out' ? 'No outstanding lendings found. Add a new lending to get started.\nTap + to add a new lending' : 'No settled lendings yet.', icon: Icons.back_hand_outlined),
        for (final x in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final c = s.lcur(x);
              final rem = s.lendRemain(x), paid = s.lendPaid(x), amt = toD(x['amount']);
              final shown = rem > 0 ? rem : paid;
              final od = '${x['due'] ?? ''}'.isNotEmpty && '${x['due']}'.compareTo(today()) < 0 && rem > 0;
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(LendingDetailScreen(id: '${x['id']}'))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: p.warn.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.back_hand_outlined, color: p.warn)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '$c · due ${'${x['due'] ?? ''}'.isEmpty ? '—' : fmtDate('${x['due']}')}'),
                          if (od) TextSpan(text: ' · overdue', style: TextStyle(color: p.neg)),
                        ]), style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(shown, c), style: TextStyle(fontWeight: FontWeight.w800, color: tab == 'out' ? p.warn : p.pos)),
                      if (c != s.base) Text('≈ ${moneyB(s, s.conv(shown, c, s.base))}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                    ]),
                  ]),
                  const SizedBox(height: 10),
                  ProgressBar(amt > 0 ? paid / amt : 0, color: p.pos),
                  const SizedBox(height: 6),
                  Text('${money(paid, c)} received of ${money(amt, c)}', style: TextStyle(color: p.muted, fontSize: 12)),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class LendingDetailScreen extends StatelessWidget {
  const LendingDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _receive(BuildContext context, J x) async {
    final s = StoreScope.read(context);
    final c = s.lcur(x);
    final r = await showSettleSheet(
      context,
      title: 'Receive Payment',
      subtitle: 'Enter the payment amount received for "${x['name']}":',
      owedCur: c,
      convert: (v, a, b) => s.conv(v, a, b),
      initCur: c,
      initAmt: '',
      accId: s.acc(x['accId']?.toString()) != null ? '${x['accId']}' : s.defaultAccId,
      hint: 'Current remaining balance: ${money(s.lendRemain(x), c)}',
      button: 'Receive Payment',
      accLabel: 'SELECT ACCOUNT',
    );
    if (r == null) return;
    s.receiveLending(id, v: r.v, cur: r.cur, accId: r.accId, date: r.date, note: r.note);
    if (context.mounted) toast(context, 'Payment received successfully');
  }

  Future<void> _editPay(BuildContext context, J x, J pm) async {
    final s = StoreScope.read(context);
    final c = s.lcur(x), pc = '${pm['payCur'] ?? c}';
    final t = s.txns.where((y) => y['id'] == pm['txId']).firstOrNull;
    final rate = pc == c ? 1.0 : (toD(pm['rate']) != 0 ? toD(pm['rate']) : s.rates.rateOf(pc, c));
    final r = await showPaySheet(
      context,
      title: 'Edit received payment',
      subtitle: '${x['name']} · ${fmtDate('${pm['date']}')}${pc != c ? ' · 1 $pc = ${rate.toStringAsFixed(4)} $c' : ''}',
      amount: toD(pm['paid'] ?? pm['amount']),
      accId: t?['accId']?.toString() ?? pm['accId']?.toString() ?? s.defaultAccId,
      currencyLabel: pc,
      date: '${pm['date']}',
      note: '${pm['note'] ?? ''}',
      walletsOnly: true,
      button: 'Save changes',
    );
    if (r == null) return;
    s.editLendPayment(id, '${pm['id']}', v: r.amount, accId: r.accId, date: r.date, note: r.note);
    if (context.mounted) toast(context, 'Payment updated');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final x = s.lending(id);
    if (x == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This lending was deleted.'));
    final c = s.lcur(x);
    String M(num v) => money(v, c);
    final amt = toD(x['amount']), paid = s.lendPaid(x), rem = s.lendRemain(x), over = math.max(0.0, paid - amt);
    final done = rem <= 0;
    final prog = amt > 0 ? math.min(100.0, paid / amt * 100) : 0.0;
    final pays = s.lendPayments(x);
    return Scaffold(
      appBar: AppBar(title: Text('${x['name']}'), actions: [
        Center(child: Badge2(done ? 'SETTLED' : 'ACTIVE', color: done ? p.pos : p.warn)),
        moreMenu([
          ('Edit lending', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(LendingFormScreen(existing: x))), false),
          (
            'Delete lending',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete lending?', 'The lending, its "lending created" transaction and all received payment transactions are removed, and your account balances are updated.')) {
                s.removeLending(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Lending deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton.icon(icon: const Icon(Icons.credit_card_rounded), label: const Text('Receive Payment'), onPressed: () => _receive(context, x))),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        GlassCard(
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Amount', style: TextStyle(color: p.muted, fontSize: 12)), Text(M(amt), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Remaining', style: TextStyle(color: p.muted, fontSize: 12)),
              Text(M(rem), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: done ? p.pos : p.warn)),
              if (c != s.base) Text('≈ ${moneyB(s, s.lendRemainB(x))}', style: TextStyle(color: p.muted, fontSize: 11.5)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          InfoTile(icon: Icons.account_balance_wallet_outlined, label: 'Amount Paid', value: M(paid), color: p.pos, valueColor: p.pos),
          InfoTile(icon: Icons.trending_up_rounded, label: 'Progress', value: '${prog.toStringAsFixed(1)}%', color: p.pos, valueColor: p.pos),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Loan Information', style: TextStyle(fontWeight: FontWeight.w800)),
            kvRow(p, 'Loan Name', '${x['name']}'),
            kvRow(p, 'Currency', '$c — ${kCurrencyMap[c]?.name ?? ''}'),
            kvRow(p, 'Original Amount', M(amt)),
            kvRow(p, 'Remaining Amount', M(rem)),
            if (over > 0) kvRow(p, 'Overpaid Amount', M(over)),
            kvRow(p, 'Due Date', '${x['due'] ?? ''}'.isEmpty ? '—' : fmtDate('${x['due']}')),
            kvRow(p, 'Given from', s.accName(x['accId'])),
            if ('${x['note'] ?? ''}'.isNotEmpty) kvRow(p, 'Note', '${x['note']}'),
            const SizedBox(height: 8),
            const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.w800)),
            kvRow(p, 'Amount Paid', M(paid)),
            kvRow(p, 'Remaining Amount', M(rem)),
            kvRow(p, 'Progress', '${prog.toStringAsFixed(1)}%'),
          ]),
        ),
        const SectionTitle('Payment History'),
        if (pays.isEmpty)
          GlassCard(child: Column(children: [Icon(Icons.credit_card_rounded, size: 40, color: p.muted), const Text('No payments yet', style: TextStyle(fontWeight: FontWeight.w800)), Text('Record the first payment to see history here', style: TextStyle(color: p.muted, fontSize: 13))]))
        else
          for (final y in pays.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                child: Row(children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(M(toD(y['amount'])), style: TextStyle(color: p.pos, fontWeight: FontWeight.w800)),
                      if (y['payCur'] != null && y['payCur'] != c) Text('Received ${money(toD(y['paid']), '${y['payCur']}')} · 1 ${y['payCur']} = ${toD(y['rate']).toStringAsFixed(4)} $c', style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(fmtDate('${y['date']}'), style: TextStyle(color: p.muted, fontSize: 12.5)),
                  moreMenu([
                    ('Edit payment', Icons.edit_outlined, () => _editPay(context, x, y), false),
                    (
                      'Delete payment',
                      Icons.delete_outline,
                      () {
                        s.deleteLendPayment(id, '${y['id']}');
                        toast(context, 'Payment deleted');
                      },
                      true
                    ),
                  ]),
                ]),
              ),
            ),
        const SectionTitle('Timeline'),
        for (final e in [
          for (final y in pays.reversed) (d: '${y['date']}', t: 'Payment Received', s: 'Payment of ${y['payCur'] != null && y['payCur'] != c ? '${money(toD(y['paid']), '${y['payCur']}')} (${M(toD(y['amount']))})' : M(toD(y['amount']))}'),
          (d: '${x['created'] ?? ''}', t: 'Lending Created', s: 'Lending of ${M(amt)} was created'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(e.t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))), if (e.d.isNotEmpty) Badge2(fmtDate(e.d).replaceAll(RegExp(r', \d{4}$'), ''), color: p.muted)]),
                Text(e.s, style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class LendingFormScreen extends StatefulWidget {
  const LendingFormScreen({super.key, this.existing});
  final J? existing;
  @override
  State<LendingFormScreen> createState() => _LendingFormScreenState();
}

class _LendingFormScreenState extends State<LendingFormScreen> {
  final name = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  late String currency;
  String? accId;
  String due = addMonths(today(), 1);
  String taken = today();
  String? err;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final x = widget.existing;
    accId = s.defaultAccId;
    currency = s.accCur(accId);
    if (x != null) {
      final gt = s.lendGiveTx(x);
      name.text = '${x['name'] ?? ''}';
      amount.text = plainNum(toD(x['amount']));
      currency = s.lcur(x);
      accId = gt?['accId']?.toString() ?? x['accId']?.toString() ?? s.defaultAccId;
      due = '${x['due'] ?? addMonths(today(), 1)}';
      taken = '${gt?['date'] ?? x['created'] ?? today()}';
      note.text = '${x['note'] ?? ''}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    final v = parseAmount(amount.text) ?? 0;
    String? e;
    if (name.text.trim().isEmpty) {
      e = 'Enter the person’s name.';
    } else if (v <= 0) {
      e = 'Enter an amount above zero.';
    } else if (accId == null) {
      e = 'Choose the account the money came from.';
    }
    if (e != null) return setState(() => err = e);
    final isNew = widget.existing == null;
    final id = s.saveLending(id: widget.existing?['id']?.toString(), name: name.text.trim(), currency: currency, amount: v, accId: accId!, due: due, note: note.text, taken: taken);
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    nav.pop();
    if (isNew) nav.push(pageRoute(LendingDetailScreen(id: id)));
    toast(context, isNew ? 'Lending and transactions created successfully' : 'Lending updated');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final x = widget.existing;
    final locked = x != null && s.lendPayments(x).isNotEmpty;
    final v = parseAmount(amount.text) ?? 0;
    final ac = accId == null ? null : s.accCur(accId);
    return Scaffold(
      appBar: AppBar(title: Text(x != null ? 'Edit Lending' : 'New Lending')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton(onPressed: _save, child: Text(x != null ? 'Save changes' : 'Save')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: "Person's name")),
        const SizedBox(height: 12),
        FieldRow(
          icon: locked ? Icons.lock_outline_rounded : Icons.currency_exchange_rounded,
          label: locked ? 'Lending currency · can’t change after payments are received' : 'Lending currency',
          value: '$currency — ${kCurrencyMap[currency]?.name ?? ''}',
          onTap: locked
              ? null
              : () async {
                  final c = await pickCurrency(context, currency);
                  if (c != null) setState(() => currency = c);
                },
        ),
        AmountBox(controller: amount, currency: currency, onChanged: (_) => setState(() => err = null)),
        const SectionTitle('Paid from account'),
        AccountChips(value: accId, onChanged: (v) => setState(() => accId = v)),
        if (ac != null && ac != currency && v > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${money(s.conv(v, currency, ac), ac)} will be taken from ${s.accName(accId)} (1 $currency = ${s.rates.rateOf(currency, ac).toStringAsFixed(4)} $ac).', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ),
        const SizedBox(height: 12),
        DateButton(value: taken, label: 'Lending taken date', onChanged: (v) => setState(() => taken = v)),
        const SizedBox(height: 12),
        DateButton(value: due, label: 'Due date', onChanged: (v) => setState(() => due = v)),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: TextStyle(color: p.neg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
