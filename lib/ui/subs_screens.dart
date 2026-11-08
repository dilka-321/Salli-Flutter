import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

const _per = {'weekly': 'wk', 'monthly': 'mo', 'quarterly': 'qtr', 'yearly': 'yr'};

/// Subscriptions list — This Month card, search, All / Active / Overdue.
class SubsScreen extends StatefulWidget {
  const SubsScreen({super.key});
  @override
  State<SubsScreen> createState() => _SubsScreenState();
}

class _SubsScreenState extends State<SubsScreen> {
  String f = 'all';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final t = today();
    final mk = ym(t);
    var L = [...s.subs]..sort((a, b) => '${a['next']}'.compareTo('${b['next']}'));
    if (f == 'active') L = L.where((x) => x['active'] != false).toList();
    if (f == 'overdue') L = L.where((x) => x['active'] != false && '${x['next']}'.compareTo(t) < 0).toList();
    if (q.isNotEmpty) L = L.where((x) => '${x['name']}'.toLowerCase().contains(q.toLowerCase())).toList();
    var paid = 0.0;
    for (final x in s.subs) {
      for (final pm in s.subPayments(x)) {
        if (ym('${pm['date']}') == mk) paid += s.conv(toD(pm['amount']), '${x['currency'] ?? s.base}', s.base);
      }
    }
    final due = s.subs.where((x) => x['active'] != false && ym('${x['next']}') == mk).fold(0.0, (a, x) => a + s.conv(toD(x['amount']), '${x['currency'] ?? s.base}', s.base)) + paid;
    final monthly = s.subs.where((x) => x['active'] != false).fold(0.0, (a, x) => a + s.subMonthly(x));
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions'), actions: [
        IconButton(tooltip: 'Add subscription', icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const SubEditScreen()))),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This Month', style: TextStyle(color: p.muted)),
            Text(moneyB(s, paid), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ProgressBar(due > 0 ? paid / due : 0, color: p.accent),
            const SizedBox(height: 8),
            Text('${moneyB(s, paid)} paid${due > 0 ? ' of ${moneyB(s, due)}' : ''} · ${moneyB(s, monthly)}/month total', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
          icon: const Icon(Icons.event_rounded),
          label: const Text('View upcoming payments'),
          onPressed: () => _upcoming(context),
        ),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search subscriptions...'),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final e in const {'all': 'All', 'active': 'Active', 'overdue': 'Overdue'}.entries) ChoiceChip(label: Text(e.value), selected: f == e.key, onSelected: (_) => setState(() => f = e.key)),
        ]),
        const SizedBox(height: 6),
        if (L.isEmpty)
          EmptyNote(s.subs.isEmpty ? 'No subscriptions yet\nTap + to add Netflix, Spotify, gym…' : 'Nothing matches.', icon: Icons.subscriptions_outlined)
        else
          for (final x in L) Padding(padding: const EdgeInsets.only(top: 10), child: _SubCard(x: x)),
      ]),
    );
  }

  void _upcoming(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final s = StoreScope.of(c);
        final p = Palette.of(c);
        final rows = <(String, J)>[];
        final end = addDays(today(), 60);
        for (final x in s.subs.where((x) => x['active'] != false)) {
          var d = '${x['next']}';
          var n = 0;
          while (d.compareTo(end) <= 0 && n < 60) {
            rows.add((d, x));
            d = advanceDate(d, '${x['freq'] ?? 'monthly'}');
            n++;
          }
        }
        rows.sort((a, b) => a.$1.compareTo(b.$1));
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
            const Text('Upcoming payments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text('Next 60 days', style: TextStyle(color: p.muted)),
            const SizedBox(height: 10),
            if (rows.isEmpty) const EmptyNote('No upcoming payments.'),
            for (final r in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: LetterTile('${r.$2['name']}', color: r.$1.compareTo(today()) < 0 ? p.neg : p.accent, size: 42),
                title: Text('${r.$2['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(r.$1.compareTo(today()) < 0 ? '${fmtDate(r.$1)} · overdue' : fmtDate(r.$1), style: TextStyle(color: r.$1.compareTo(today()) < 0 ? p.neg : p.muted)),
                trailing: Text(money(toD(r.$2['amount']), '${r.$2['currency'] ?? s.base}'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ]),
        );
      },
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.x});
  final J x;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final paused = x['active'] == false;
    final next = '${x['next']}';
    final od = !paused && next.compareTo(today()) < 0;
    final dl = diffDays(today(), next);
    return GlassCard(
      onTap: () => Navigator.of(context).push(pageRoute(SubDetailScreen(id: '${x['id']}'))),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        LetterTile('${x['name']}', color: paused ? p.muted : p.neg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${x['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(
              paused ? 'Paused' : od ? 'Overdue · ${fmtDate(next)}' : dl == 0 ? 'Due today' : 'Next ${fmtDate(next)} · in $dl day${dl == 1 ? '' : 's'}',
              style: TextStyle(color: od ? p.neg : p.muted, fontSize: 12.5, fontWeight: od ? FontWeight.w700 : FontWeight.w400),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(toD(x['amount']), '${x['currency'] ?? s.base}'), style: TextStyle(fontWeight: FontWeight.w800, color: p.neg)),
          Text('/ ${_per[x['freq']] ?? 'mo'}', style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
      ]),
    );
  }
}

/// Subscription details: tiles, Pay now, payment history (edit / delete each payment).
class SubDetailScreen extends StatelessWidget {
  const SubDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _pay(BuildContext context, J x) async {
    final s = StoreScope.read(context);
    final accId = s.acc(x['accId']?.toString()) != null ? '${x['accId']}' : s.defaultAccId;
    if (accId == null) return toast(context, 'Create an account first');
    final r = await showPaySheet(
      context,
      title: 'Pay ${x['name']}',
      subtitle: 'Due ${fmtDate('${x['next']}')}',
      amount: s.conv(toD(x['amount']), '${x['currency'] ?? s.base}', s.accCur(accId)),
      accId: accId,
      note: '${x['name']}',
      button: 'Pay now',
    );
    if (r == null) return;
    s.paySub(id: id, accId: r.accId, amount: r.amount, date: r.date, note: r.note.isEmpty ? '${x['name']}' : r.note);
    if (context.mounted) toast(context, 'Payment recorded');
  }

  Future<void> _editPayment(BuildContext context, J x, J pm) async {
    final s = StoreScope.read(context);
    final t = s.txns.where((y) => y['id'] == pm['txId']).firstOrNull;
    final r = await showPaySheet(
      context,
      title: 'Edit payment',
      subtitle: '${x['name']} · ${fmtDate('${pm['date']}')}',
      amount: t != null ? toD(t['amount']) : toD(pm['amount']),
      accId: t?['accId']?.toString() ?? x['accId']?.toString() ?? s.defaultAccId,
      date: '${pm['date']}',
      note: t != null ? '${t['note'] ?? ''}' : '${x['name']}',
      button: 'Save changes',
    );
    if (r == null) return;
    s.editSubPayment(id, '${pm['id']}', amount: r.amount, accId: r.accId, date: r.date, note: r.note);
    if (context.mounted) toast(context, 'Payment updated');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final x = s.sub(id);
    if (x == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This subscription was deleted.'));
    final cur = '${x['currency'] ?? s.base}';
    final paused = x['active'] == false;
    final od = '${x['next']}'.compareTo(today()) < 0;
    final pays = s.subPayments(x).reversed.toList();
    final total = pays.fold(0.0, (a, pm) => a + toD(pm['amount']));
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(pageRoute(SubEditScreen(existing: x)))),
        moreMenu([
          (paused ? 'Resume' : 'Pause', Icons.schedule_rounded, () => s.toggleSub(id), false),
          (
            'Delete',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete subscription?', 'Delete "${x['name']}"? This cannot be undone.')) {
                s.deleteSub(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Subscription deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              LetterTile('${x['name']}', color: p.neg, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Badge2(paused ? 'Paused' : 'Active', color: paused ? p.muted : p.pos),
                ]),
              ),
            ]),
            Divider(height: 26, color: p.line),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(toD(x['amount']), cur), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: p.neg)),
              Text('  / ${_per[x['freq']] ?? 'mo'}', style: TextStyle(color: p.muted)),
              const Spacer(),
              if (x['catId'] != null) Text('${s.cat(x['catId'])?['icon'] ?? ''} ${s.cat(x['catId'])?['name'] ?? ''}', style: TextStyle(color: p.muted)),
            ]),
            if (cur != s.base) Text('≈ ${moneyB(s, s.subMonthly(x))} per month', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          InfoTile(icon: Icons.event_rounded, label: 'Next payment', value: fmtDate('${x['next']}'), color: p.neg, valueColor: od && !paused ? p.neg : null),
          InfoTile(icon: Icons.repeat_rounded, label: 'Frequency', value: kSubFreq[x['freq']] ?? 'Monthly'),
          InfoTile(icon: Icons.payments_outlined, label: 'Total paid', value: money(total, cur), color: p.pos),
          InfoTile(icon: Icons.receipt_outlined, label: 'Payments', value: '${pays.length} payments'),
          InfoTile(icon: Icons.calendar_month_rounded, label: 'Started', value: fmtDate('${x['start'] ?? today()}'), color: p.muted),
          InfoTile(icon: Icons.autorenew_rounded, label: 'Auto-renew', value: x['autoRenew'] == true ? 'Yes' : 'No', color: p.pos, valueColor: x['autoRenew'] == true ? p.pos : null),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(icon: const Icon(Icons.check_rounded), label: const Text('Pay now'), onPressed: () => _pay(context, x)),
        const SectionTitle('Payment History'),
        if (pays.isEmpty)
          const EmptyNote('No payments yet. Tap Pay now to record one.', icon: Icons.history_rounded)
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [
              for (var i = 0; i < pays.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.line),
                Builder(builder: (_) {
                  final pm = pays[i];
                  final t = s.txns.where((y) => y['id'] == pm['txId']).firstOrNull;
                  final sub = t == null ? '' : '${s.accName(t['accId'])}${'${t['note'] ?? ''}'.isNotEmpty && t['note'] != x['name'] ? ' · ${t['note']}' : ''}';
                  return Row(children: [
                    Expanded(child: kvRow(p, fmtDate('${pm['date']}'), money(toD(pm['amount']), cur), sub: sub)),
                    moreMenu([
                      ('Edit payment', Icons.edit_outlined, () => _editPayment(context, x, pm), false),
                      (
                        'Delete payment',
                        Icons.delete_outline,
                        () async {
                          if (await confirmDialog(context, 'Delete payment?', 'This payment and its transaction are removed, and the next payment date goes back.')) {
                            s.deleteSubPayment(id, '${pm['id']}');
                            if (context.mounted) toast(context, 'Payment deleted');
                          }
                        },
                        true
                      ),
                    ]),
                  ]);
                }),
              ],
            ]),
          ),
        if ('${x['notes'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Notes', style: TextStyle(fontWeight: FontWeight.w800)), Text('${x['notes']}', style: TextStyle(color: p.muted))])),
        ],
      ]),
    );
  }
}

/// Add / edit subscription — same fields as the web form.
class SubEditScreen extends StatefulWidget {
  const SubEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<SubEditScreen> createState() => _SubEditScreenState();
}

class _SubEditScreenState extends State<SubEditScreen> {
  final name = TextEditingController();
  final amount = TextEditingController();
  final notes = TextEditingController();
  final remindCustomDays = TextEditingController();
  late String currency;
  String? catId, accId;
  String start = today();
  String freq = 'monthly';
  String next = addMonths(today(), 1);
  bool autoRenew = true, remind = false, remindCustom = false;
  int remindDays = 3;
  String? rdErr;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final e = widget.existing;
    currency = s.base;
    if (e != null) {
      name.text = '${e['name'] ?? ''}';
      amount.text = plainNum(toD(e['amount']));
      notes.text = '${e['notes'] ?? ''}';
      currency = '${e['currency'] ?? s.base}';
      catId = e['catId']?.toString();
      accId = e['accId']?.toString();
      start = '${e['start'] ?? today()}';
      freq = '${e['freq'] ?? 'monthly'}';
      next = '${e['next'] ?? advanceDate(start, freq)}';
      autoRenew = e['autoRenew'] != false;
      remind = e['remind'] == true;
      remindCustom = e['remindCustom'] == true;
      remindDays = int.tryParse('${e['remindDays'] ?? 3}') ?? 3;
      remindCustomDays.text = '$remindDays';
    }
  }

  @override
  void dispose() {
    for (final c in [name, amount, notes, remindCustomDays]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    final amt = parseAmount(amount.text) ?? 0;
    var rd = remindDays;
    if (remind && remindCustom) {
      final d = int.tryParse(remindCustomDays.text.trim());
      if (d == null || d < 1 || d > 90) return setState(() => rdErr = 'Enter a number of days from 1 to 90.');
      rd = d;
    }
    if (name.text.trim().isEmpty) return toast(context, 'Enter a name');
    if (amt <= 0) return toast(context, 'Enter an amount above zero');
    final e = widget.existing;
    final rec = <String, dynamic>{
      if (e != null) 'id': e['id'],
      'name': name.text.trim(),
      'amount': amt,
      'currency': currency,
      'catId': catId,
      'start': start,
      'freq': freq,
      'next': next,
      'accId': accId,
      'notes': notes.text,
      'autoRenew': autoRenew,
      'remind': remind,
      'remindDays': rd,
      'remindCustom': remindCustom,
      if (e != null) 'active': e['active'] != false,
    };
    HapticFeedback.lightImpact();
    s.saveSub(rec);
    Navigator.pop(context);
    toast(context, e != null ? 'Subscription updated' : 'Subscription added');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final isNew = widget.existing == null;
    final c = s.cat(catId);
    return Scaffold(
      appBar: AppBar(title: Text('${isNew ? 'Add' : 'Edit'} Subscription')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        TextField(controller: name, autofocus: isNew, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Netflix, Spotify', prefixIcon: Icon(Icons.sell_outlined))),
        const SizedBox(height: 12),
        AmountBox(controller: amount, currency: currency, color: p.neg),
        const SizedBox(height: 12),
        FieldRow(
          icon: Icons.currency_exchange_rounded,
          label: 'Currency',
          value: '$currency — ${kCurrencyMap[currency]?.name ?? ''}',
          onTap: () async {
            final x = await pickCurrency(context, currency);
            if (x != null) setState(() => currency = x);
          },
        ),
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
        const SectionTitle('Billing'),
        Row(children: [
          Expanded(
            child: DateButton(
              value: start,
              label: 'Start',
              onChanged: (v) => setState(() {
                start = v;
                if (isNew) next = advanceDate(v, freq);
              }),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kSubFreq.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: freq == e.key,
              onSelected: (_) => setState(() {
                freq = e.key;
                if (isNew) next = advanceDate(start, freq);
              }),
            ),
        ]),
        const SizedBox(height: 10),
        DateButton(value: next, label: 'Next payment date', onChanged: (v) => setState(() => next = v)),
        SectionTitle('Billed to (optional)', action: accId != null ? '✕ Clear' : null, onAction: () => setState(() => accId = null)),
        AccountChips(value: accId, onChanged: (v) => setState(() => accId = v)),
        const SizedBox(height: 14),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Plan details, promo info', prefixIcon: Icon(Icons.notes_rounded))),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(children: [
            SwitchListTile(
              title: const Text('Auto-renew', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Automatically renew this subscription'),
              value: autoRenew,
              onChanged: (v) => setState(() => autoRenew = v),
            ),
            Divider(height: 1, color: p.line),
            SwitchListTile(
              title: const Text('Remind me before renewal', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Saved with the subscription (reminders are sent by the Salli app)'),
              value: remind,
              onChanged: (v) => setState(() => remind = v),
            ),
            if (remind)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final d in [1, 3, 7, 14])
                      ChoiceChip(
                        label: Text('$d day${d > 1 ? 's' : ''} before'),
                        selected: !remindCustom && remindDays == d,
                        onSelected: (_) => setState(() {
                          remindDays = d;
                          remindCustom = false;
                        }),
                      ),
                    ChoiceChip(label: const Text('Custom...'), selected: remindCustom, onSelected: (_) => setState(() => remindCustom = true)),
                  ]),
                  if (remindCustom) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: remindCustomDays,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Days before renewal', hintText: '1 - 90', errorText: rdErr),
                      onChanged: (_) => setState(() => rdErr = null),
                    ),
                  ],
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(icon: const Icon(Icons.check_rounded), onPressed: _save, label: const Text('Save')),
      ]),
    );
  }
}
