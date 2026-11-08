import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

const _per = {'daily': 'day', 'weekly': 'wk', 'monthly': 'mo', 'yearly': 'yr'};

String _recName(AppStore s, J r) {
  final t = '${r['title'] ?? ''}'.trim();
  return t.isNotEmpty ? t : '${s.cat(r['catId'])?['name'] ?? 'Recurring'}';
}

/// Make Payment for a recurring expense (records the expense for the current due date).
Future<void> recPay(BuildContext context, String id) async {
  final s = StoreScope.read(context);
  final r = s.rec(id);
  if (r == null) return;
  if (s.accounts.isEmpty) return toast(context, 'Create an account first');
  final accId = s.acc(r['accId']?.toString()) != null ? '${r['accId']}' : s.defaultAccId;
  final res = await showPaySheet(
    context,
    title: 'Make Payment',
    subtitle: '${_recName(s, r)} · due ${fmtDate('${r['next']}')}',
    amount: toD(r['amount']),
    accId: accId,
    note: '${r['title'] ?? ''}',
  );
  if (res == null) return;
  s.payRec(id: id, accId: res.accId, amount: res.amount, date: res.date, catId: '${r['catId']}', note: res.note);
  if (context.mounted) toast(context, 'Payment recorded');
}

Future<void> _recDelete(BuildContext context, String id, {bool pop = false}) async {
  final s = StoreScope.read(context);
  if (await confirmDialog(context, 'Delete recurring expense?', 'Payments you already recorded stay in your transactions.')) {
    s.deleteRec(id);
    if (context.mounted) {
      if (pop) Navigator.pop(context);
      toast(context, 'Recurring expense deleted');
    }
  }
}

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.recurring;
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Expenses'), actions: [
        IconButton(tooltip: 'Add', icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const RecEditScreen()))),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (L.isEmpty) ...[
          const EmptyNote('No recurring expenses yet\nRent, bills and other regular payments — record each one with Make Payment.', icon: Icons.repeat_rounded),
          Center(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add Recurring Expense'), onPressed: () => Navigator.of(context).push(pageRoute(const RecEditScreen())))),
        ],
        for (final r in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final m = s.recMissed(r);
              final c = s.accCur(r['accId']?.toString());
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(RecDetailScreen(id: '${r['id']}'))),
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(children: [
                  EmojiTile('${s.cat(r['catId'])?['icon'] ?? '🔁'}', tint: p.warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_recName(s, r), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Text('${kRecFreq[r['freq']] ?? 'Monthly'} · next ${fmtDate('${r['next']}')}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      if (m > 0) Text('$m missed period${m == 1 ? '' : 's'}', style: TextStyle(color: p.neg, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(toD(r['amount']), c), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('/ ${_per[r['freq']] ?? 'mo'}', style: TextStyle(color: p.muted, fontSize: 12)),
                  ]),
                  moreMenu([
                    ('Make Payment', Icons.credit_card_rounded, () => recPay(context, '${r['id']}'), false),
                    ('Edit', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(RecEditScreen(existing: r))), false),
                    ('Delete', Icons.delete_outline, () => _recDelete(context, '${r['id']}'), true),
                  ]),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class RecDetailScreen extends StatelessWidget {
  const RecDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final r = s.rec(id);
    if (r == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This recurring expense was deleted.'));
    final c = s.accCur(r['accId']?.toString());
    final m = s.recMissed(r);
    final name = _recName(s, r);
    final pays = s.recPayments(r).reversed.toList();
    final total = pays.fold(0.0, (a, x) => a + toD(x['amount']));
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Detail'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(pageRoute(RecEditScreen(existing: r)))),
        moreMenu([('Delete', Icons.delete_outline, () => _recDelete(context, id, pop: true), true)]),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              LetterTile(name, color: p.accent, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Badge2('Active', color: p.pos),
                ]),
              ),
            ]),
            Divider(height: 26, color: p.line),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(toD(r['amount']), c), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.accent)),
              Text('  / ${_per[r['freq']] ?? 'mo'}', style: TextStyle(color: p.muted)),
              const Spacer(),
              Text('${s.cat(r['catId'])?['icon'] ?? ''} ${s.cat(r['catId'])?['name'] ?? ''}', style: TextStyle(color: p.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          InfoTile(icon: Icons.event_rounded, label: 'Next due', value: fmtDate('${r['next']}'), valueColor: m > 0 ? p.neg : p.accent),
          InfoTile(icon: Icons.repeat_rounded, label: 'Frequency', value: kRecFreq[r['freq']] ?? 'Daily'),
          InfoTile(icon: Icons.payments_outlined, label: 'Total paid', value: money(total, c), color: p.pos),
          InfoTile(icon: Icons.warning_amber_rounded, label: 'Missed periods', value: '$m', color: m > 0 ? p.neg : p.muted, valueColor: m > 0 ? p.neg : null),
        ]),
        const SizedBox(height: 12),
        InfoTile(icon: Icons.calendar_month_rounded, label: 'Start date', value: fmtDate('${r['start'] ?? today()}'), color: p.muted),
        const SizedBox(height: 14),
        FilledButton.icon(icon: const Icon(Icons.credit_card_rounded), label: const Text('Make Payment'), onPressed: () => recPay(context, id)),
        const SectionTitle('Payment History'),
        if (pays.isEmpty)
          const EmptyNote('No payments yet. Tap Make Payment to record.', icon: Icons.history_rounded)
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              for (var i = 0; i < pays.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.line),
                Row(children: [
                  Expanded(
                    child: kvRow(
                      p,
                      fmtDate('${pays[i]['date']}'),
                      money(toD(pays[i]['amount']), s.accCur(pays[i]['accId']?.toString())),
                      sub: '${s.accName(pays[i]['accId'])}${pays[i]['due'] != null ? ' · for ${fmtDate('${pays[i]['due']}')}' : ''}',
                    ),
                  ),
                  moreMenu([
                    (
                      'Delete payment',
                      Icons.delete_outline,
                      () async {
                        if (await confirmDialog(context, 'Delete payment?', 'The payment and its transaction are removed. If it was the latest, its due date becomes due again.')) {
                          s.deleteRecPayment(id, '${pays[i]['id']}');
                          if (context.mounted) toast(context, 'Payment deleted');
                        }
                      },
                      true
                    ),
                  ]),
                ]),
              ],
            ]),
          ),
      ]),
    );
  }
}

class RecEditScreen extends StatefulWidget {
  const RecEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<RecEditScreen> createState() => _RecEditScreenState();
}

class _RecEditScreenState extends State<RecEditScreen> {
  final amount = TextEditingController();
  final title = TextEditingController();
  String? catId, accId;
  String freq = 'monthly';
  int dom = DateTime.now().day;
  String start = today();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final e = widget.existing;
    if (e != null) {
      amount.text = plainNum(toD(e['amount']));
      title.text = '${e['title'] ?? ''}';
      catId = e['catId']?.toString();
      accId = e['accId']?.toString();
      freq = '${e['freq'] ?? 'monthly'}';
      dom = int.tryParse('${e['dom'] ?? 1}') ?? 1;
      start = '${e['start'] ?? today()}';
    } else {
      catId = s.categories.where((c) => c['kind'] == 'expense').firstOrNull?['id']?.toString();
      accId = s.defaultAccId;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    title.dispose();
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    final amt = parseAmount(amount.text) ?? 0;
    if (amt <= 0) return toast(context, 'Enter an amount above zero');
    final e = widget.existing;
    final rec = <String, dynamic>{
      if (e != null) ...e,
      'title': title.text,
      'amount': amt,
      'catId': catId,
      'freq': freq,
      'dom': dom,
      'start': start,
      'accId': accId,
    };
    HapticFeedback.lightImpact();
    s.saveRec(rec);
    Navigator.pop(context);
    toast(context, 'Recurring expense saved');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final c = s.cat(catId);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.existing == null ? 'Add' : 'Edit'} Recurring Expense')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        AmountBox(controller: amount, currency: s.accCur(accId), autofocus: widget.existing == null),
        const SizedBox(height: 12),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. House rent')),
        const SizedBox(height: 12),
        FieldRow(
          icon: Icons.category_outlined,
          label: 'Category',
          value: c == null ? 'Select category' : '${c['icon']} ${c['name']}',
          onTap: () async {
            final x = await pickCategory(context, current: catId);
            if (x != null) setState(() => catId = x);
          },
        ),
        const SectionTitle('Frequency'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kRecFreq.entries) ChoiceChip(label: Text(e.value), selected: freq == e.key, onSelected: (_) => setState(() => freq = e.key)),
        ]),
        if (freq == 'monthly') ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: dom.clamp(1, 31).toInt(),
            decoration: const InputDecoration(labelText: 'Day of month (1-31)'),
            items: [for (var i = 1; i <= 31; i++) DropdownMenuItem(value: i, child: Text('$i'))],
            onChanged: (v) => setState(() => dom = v ?? dom),
          ),
        ],
        const SizedBox(height: 14),
        DateButton(value: start, label: 'Start date', onChanged: (v) => setState(() => start = v)),
        const SectionTitle('Account'),
        AccountChips(value: accId, onChanged: (v) => setState(() => accId = v)),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ]),
    );
  }
}
