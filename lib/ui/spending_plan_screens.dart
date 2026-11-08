import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/planning.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'transfers_screen.dart';
import 'tx_edit_screen.dart';
import 'widgets.dart';

String _range(J p) => '${fmtDate('${p['start']}').replaceAll(RegExp(r', \d{4}$'), '')} – ${'${p['end'] ?? ''}'.isEmpty ? 'No end date' : fmtDate('${p['end']}')}';

Color _moodColor(Palette p, String c) => c == 'red' ? p.neg : c == 'orange' ? p.warn : p.pos;

Future<void> _delete(BuildContext context, String id, {bool pop = false}) async {
  final s = StoreScope.read(context);
  if (await confirmDialog(context, 'Delete spending plan?', 'Linked transactions stay in your records; they are just unlinked from this plan.')) {
    s.deleteSplan(id);
    if (context.mounted) {
      if (pop) Navigator.pop(context);
      toast(context, 'Spending plan deleted');
    }
  }
}

/// "Add Planned Expense" sheet → {id, amount, catId, note}
Future<J?> plannedSheet(BuildContext context) {
  final amt = TextEditingController();
  final note = TextEditingController();
  String? catId, err;
  return showModalBottomSheet<J>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final s = StoreScope.of(c);
      final p = Palette.of(c);
      final ct = s.cat(catId);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Add Planned Expense', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              AmountBox(controller: amt, currency: s.base, label: 'Amount *', autofocus: true),
              const SizedBox(height: 12),
              FieldRow(
                icon: Icons.category_outlined,
                label: 'Category *',
                value: ct == null ? 'Select category' : '${ct['icon']} ${ct['name']}',
                muted: ct == null,
                onTap: () async {
                  final x = await pickCategory(c, current: catId);
                  if (x != null) set(() => catId = x);
                },
              ),
              TextField(controller: note, maxLines: 2, minLines: 1, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Add notes...')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final v = parseAmount(amt.text) ?? 0;
                  if (v <= 0) return set(() => err = 'Enter an amount above zero.');
                  if (catId == null) return set(() => err = 'Choose a category.');
                  Navigator.pop(c, <String, dynamic>{'id': uid(), 'amount': round2(v), 'catId': catId, 'note': note.text.trim()});
                },
                child: const Text('Save'),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

class SpendingPlansScreen extends StatelessWidget {
  const SpendingPlansScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = [...s.splans]..sort((a, b) => '${b['start']}'.compareTo('${a['start']}'));
    void create() => Navigator.of(context).push(pageRoute(const SplanEditScreen()));
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Spending Plan'), Text('Manage your spending plans & budgets', style: TextStyle(color: p.muted, fontSize: 12.5))])),
      floatingActionButton: FloatingActionButton(onPressed: create, child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        if (L.isEmpty) ...[
          const EmptyNote('No spending plans yet\nPlan a trip, an event or a month: set a budget, list planned expenses and track what you actually spend', icon: Icons.event_note_rounded),
          Center(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Create Spending Plan'), onPressed: create)),
        ],
        for (final pl in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final st = s.splanStats(pl);
              final lab = st.ratio > 1 ? ('Over', p.neg) : st.ratio >= .9 ? ('Warning', p.warn) : ('Safe', p.pos);
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(SplanDetailScreen(id: '${pl['id']}'))),
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: p.pos.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.calendar_month_rounded, color: p.pos)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${pl['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text(_range(pl), style: TextStyle(color: p.muted, fontSize: 12.5))])),
                    Text(moneyB(s, st.cap), style: TextStyle(color: p.pos, fontWeight: FontWeight.w800)),
                    moreMenu([
                      ('Edit', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(SplanEditScreen(existing: pl))), false),
                      ('Delete', Icons.delete_outline, () => _delete(context, '${pl['id']}'), true),
                    ]),
                  ]),
                  if ('${pl['desc'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6, right: 12), child: Text('${pl['desc']}', style: TextStyle(color: p.muted, fontSize: 13))),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Divider(height: 18, color: p.line),
                      Row(children: [Expanded(child: Text('Budget Progress', style: TextStyle(color: p.muted, fontSize: 12.5))), Text('${moneyB(s, st.spent)} spent', style: TextStyle(color: p.muted, fontSize: 12.5))]),
                      const SizedBox(height: 6),
                      ProgressBar(st.ratio, color: lab.$2),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: Text('${(st.ratio * 100).round()}% ● ${lab.$1}', style: TextStyle(color: lab.$2, fontSize: 12.5))),
                        Text('${moneyB(s, st.rem.abs())} ${st.rem < 0 ? 'over' : 'left'}', style: TextStyle(color: st.rem < 0 ? p.neg : p.pos, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ]),
                    ]),
                  ),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class SplanEditScreen extends StatefulWidget {
  const SplanEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<SplanEditScreen> createState() => _SplanEditScreenState();
}

class _SplanEditScreenState extends State<SplanEditScreen> {
  final name = TextEditingController();
  final desc = TextEditingController();
  final limit = TextEditingController();
  String start = today();
  String end = '';
  List<J> planned = [];
  String? errName, errEnd;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      name.text = '${e['name'] ?? ''}';
      desc.text = '${e['desc'] ?? ''}';
      limit.text = toD(e['limit']) != 0 ? plainNum(toD(e['limit'])) : '';
      start = '${e['start'] ?? today()}';
      end = '${e['end'] ?? ''}';
      planned = ((e['planned'] as List?) ?? const []).whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
    }
  }

  @override
  void dispose() {
    name.dispose();
    desc.dispose();
    limit.dispose();
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    setState(() {
      errName = name.text.trim().isEmpty ? 'Please enter a name' : null;
      errEnd = end.isNotEmpty && end.compareTo(start) < 0 ? 'End date must be on or after the start date' : null;
    });
    if (errName != null || errEnd != null) return;
    final e = widget.existing;
    final id = s.saveSplan({
      if (e != null) 'id': e['id'],
      'name': name.text.trim(),
      'desc': desc.text.trim(),
      'start': start,
      'end': end,
      'limit': parseAmount(limit.text) ?? 0,
      'planned': planned,
      'created': e?['created'] ?? today(),
    });
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    nav.pop();
    if (e == null) nav.push(pageRoute(SplanDetailScreen(id: id)));
    toast(context, e != null ? 'Spending plan updated' : 'Spending plan created');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Spending Plan' : 'Create Spending Plan')),
      bottomNavigationBar: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton(onPressed: _save, child: Text(widget.existing != null ? 'Save Spending Plan' : 'Create Spending Plan'))),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        TextField(controller: name, decoration: InputDecoration(labelText: 'Spending Plan Name *', hintText: 'Enter spending plan name', errorText: errName)),
        const SizedBox(height: 12),
        TextField(controller: desc, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Description', hintText: 'Enter description (optional)')),
        const SizedBox(height: 12),
        DateButton(value: start, label: 'Start Date', onChanged: (v) => setState(() => start = v)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(end.isEmpty ? 'End Date (Optional)' : 'End Date: ${fmtDate(end)}'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: parseDate(end.isEmpty ? start : end), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => end = isoDate(d));
              },
            ),
          ),
          if (end.isNotEmpty) IconButton(onPressed: () => setState(() => end = ''), icon: const Icon(Icons.close_rounded)),
        ]),
        if (errEnd != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(errEnd!, style: TextStyle(color: p.neg))),
        const SizedBox(height: 12),
        TextField(controller: limit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Budget Limit (Optional)', hintText: 'Enter budget limit', prefixText: '${currencySymbol(s.base)} ')),
        const SectionTitle('Planned expenses (optional)'),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Planned Expense'),
          onPressed: () async {
            final x = await plannedSheet(context);
            if (x != null) setState(() => planned.add(x));
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Add expected costs like rent or catering', style: TextStyle(color: p.muted, fontSize: 12))),
        for (var i = 0; i < planned.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: Row(children: [
                EmojiTile('${s.cat(planned[i]['catId']?.toString())?['icon'] ?? '📦'}', size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.cat(planned[i]['catId']?.toString())?['name'] ?? 'Category'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${moneyB(s, toD(planned[i]['amount']))}${'${planned[i]['note'] ?? ''}'.isNotEmpty ? ' · ${planned[i]['note']}' : ''}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ]),
                ),
                IconButton(onPressed: () => setState(() => planned.removeAt(i)), icon: Icon(Icons.delete_outline, color: p.neg)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class SplanDetailScreen extends StatefulWidget {
  const SplanDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<SplanDetailScreen> createState() => _SplanDetailScreenState();
}

class _SplanDetailScreenState extends State<SplanDetailScreen> {
  String sort = 'date', show = 'all';
  String? catF;

  void _addMenu(J pl) {
    final s = StoreScope.read(context);
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded),
            title: const Text('Add Transaction'),
            onTap: () async {
              Navigator.pop(c);
              if (s.accounts.isEmpty) return toast(context, 'Create an account first');
              final catId = await pickCategory(context);
              if (catId == null || !mounted) return;
              final d = s.splanActive(pl) ? today() : '${pl['start']}';
              Navigator.of(context).push(pageRoute(TxEditScreen(type: 'expense', planId: widget.id, presetCatId: catId, presetDate: d)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.repeat_rounded),
            title: const Text('Add Planned Expense'),
            onTap: () async {
              Navigator.pop(c);
              final x = await plannedSheet(context);
              if (x != null) {
                s.addPlanned(widget.id, x);
                if (mounted) toast(context, 'Planned expense added');
              }
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pick(String title, Map<String, String> opts, ValueChanged<String> on) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final e in opts.entries) ListTile(title: Text(e.value), onTap: () => Navigator.pop(c, e.key)),
        ]),
      ),
    );
    if (v != null) setState(() => on(v));
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final pl = s.splan(widget.id);
    if (pl == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This spending plan was deleted.'));
    final st = s.splanStats(pl);
    final planned = ((pl['planned'] as List?) ?? const []).whereType<Map>().map((x) => x as J).toList();
    final byCat = <String, (double, double)>{};
    for (final x in planned) {
      final k = '${x['catId']}';
      byCat[k] = ((byCat[k]?.$1 ?? 0.0) + toD(x['amount']), 0.0);
    }
    for (final k in byCat.keys.toList()) {
      final ids = s.catAndSubs(k).toSet();
      byCat[k] = (byCat[k]!.$1, st.tx.where((t) => ids.contains('${t['catId']}')).fold(0.0, (a, t) => a + s.tBase(t)));
    }
    // rows: (isActual, tx or planned item, sortDate, catId, value)
    var rows = [
      for (final t in st.tx) (true, t, '${t['date']}${t['time'] ?? ''}', '${t['catId']}', s.tBase(t)),
      for (final x in planned) (false, x, '', '${x['catId']}', toD(x['amount'])),
    ];
    if (show == 'planned') rows = rows.where((r) => !r.$1).toList();
    if (show == 'actual') rows = rows.where((r) => r.$1).toList();
    if (catF != null) {
      final ids = s.catAndSubs(catF!).toSet();
      rows = rows.where((r) => ids.contains(r.$4)).toList();
    }
    rows.sort(sort == 'amount'
        ? (a, b) => b.$5.compareTo(a.$5)
        : sort == 'category'
            ? (a, b) => '${s.cat(a.$4)?['name'] ?? ''}'.compareTo('${s.cat(b.$4)?['name'] ?? ''}')
            : (a, b) => a.$1 == b.$1 ? b.$3.compareTo(a.$3) : (a.$1 ? -1 : 1));
    final cats = <String>{...planned.map((x) => '${x['catId']}'), ...st.tx.map((t) => '${t['catId']}')}.where((id) => s.cat(id) != null).toList();
    final mc = _moodColor(p, st.mood.$2);
    Widget tile(IconData i, Color c, String k, double v) => GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 18)),
            const SizedBox(height: 8),
            Text(k, style: TextStyle(color: p.muted, fontSize: 12.5)),
            Text(moneyB(s, v), style: TextStyle(fontWeight: FontWeight.w800, color: c)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${pl['name']}'), Text(moneyB(s, st.cap), style: TextStyle(color: p.muted, fontSize: 12.5))]),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(pageRoute(SplanEditScreen(existing: pl)))),
          IconButton(icon: Icon(Icons.delete_outline, color: p.neg), onPressed: () => _delete(context, widget.id, pop: true)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _addMenu(pl), icon: const Icon(Icons.add_rounded), label: const Text('Add Transaction')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        Center(child: Text('Remaining Balance', style: TextStyle(color: p.muted))),
        Center(child: Text(moneyB(s, st.rem), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: st.rem < 0 ? p.neg : p.pos))),
        const SizedBox(height: 12),
        tileGrid([
          tile(Icons.account_balance_rounded, p.pos, 'Budget Limit', st.limit),
          tile(Icons.repeat_rounded, const Color(0xFF5B8DEF), 'Total Planned', st.planned),
          tile(Icons.warning_amber_rounded, p.warn, 'Total Unplanned', st.unplanned),
          tile(Icons.receipt_outlined, p.pos, 'Total Spent', st.spent),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Badge2(st.mood.$1, color: mc),
                const SizedBox(height: 8),
                Text(st.mood.$3),
                Text(moneyB(s, st.rem), style: TextStyle(fontWeight: FontWeight.w800, color: st.rem < 0 ? p.neg : p.pos)),
                const SizedBox(height: 6),
                ProgressBar(st.cap != 0 ? (st.rem < 0 ? 0 : st.rem) / st.cap : 0, color: p.accent),
              ]),
            ),
            const SizedBox(width: 12),
            Text(st.mood.$4, style: const TextStyle(fontSize: 48)),
          ]),
        ),
        if (byCat.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('By category', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final e in byCat.entries)
                InkWell(
                  onTap: () => setState(() => catF = e.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      Row(children: [
                        Text('${s.cat(e.key)?['icon'] ?? ''}', style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${s.cat(e.key)?['name'] ?? 'Category'}', style: const TextStyle(fontWeight: FontWeight.w700)), Text(moneyB(s, e.value.$1), style: TextStyle(color: p.muted, fontSize: 12))])),
                        Text('${moneyB(s, e.value.$2)} / ${moneyB(s, e.value.$1)}', style: TextStyle(color: p.muted, fontSize: 12)),
                        Icon(Icons.chevron_right_rounded, size: 16, color: p.muted),
                      ]),
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final q = e.value.$1 != 0 ? e.value.$2 / e.value.$1 : 0.0;
                        return ProgressBar(q, color: q > 1 ? p.neg : p.pos, height: 6);
                      }),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            kvRow(p, 'Start Date', fmtDate('${pl['start']}')),
            kvRow(p, 'End Date', '${pl['end'] ?? ''}'.isEmpty ? 'Not set' : fmtDate('${pl['end']}')),
            kvRow(p, 'Description', '${pl['desc'] ?? ''}'.isEmpty ? '—' : '${pl['desc']}'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(children: [const Expanded(child: Text('Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))), Text('${rows.length} items', style: TextStyle(color: p.muted))]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(label: Text('Sort: ${const {'date': 'Date', 'category': 'Category', 'amount': 'Amount (highest first)'}[sort]}'), onPressed: () => _pick('Sort', const {'date': 'Date', 'category': 'Category', 'amount': 'Amount (highest first)'}, (v) => sort = v)),
          ActionChip(label: Text(const {'all': 'All', 'planned': 'Planned', 'actual': 'Actual'}[show]!), onPressed: () => _pick('Show', const {'all': 'All', 'planned': 'Planned', 'actual': 'Actual'}, (v) => show = v)),
          ActionChip(
            label: Text(catF == null ? 'Category' : '${s.cat(catF)?['name'] ?? 'Category'}'),
            onPressed: () => _pick('Category', {'': 'All categories', for (final id in cats) id: '${s.cat(id)?['name']}'}, (v) => catF = v.isEmpty ? null : v),
          ),
        ]),
        const SizedBox(height: 8),
        if (rows.isEmpty) const EmptyNote('No transactions match these filters.'),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: r.$1
                ? GlassCard(
                    onTap: () => showTxDetail(context, r.$2),
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: p.pos.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.receipt_outlined, color: p.pos)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s.cat(r.$4)?['name'] ?? s.txTitle(r.$2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${fmtDate('${r.$2['date']}')}${'${r.$2['note'] ?? ''}'.isNotEmpty ? ' · ${r.$2['note']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(moneyB(s, r.$5), style: TextStyle(color: p.neg, fontWeight: FontWeight.w800)),
                        if (s.accCur(r.$2['accId']?.toString()) != s.base) Text(money(toD(r.$2['amount']), s.accCur(r.$2['accId']?.toString())), style: TextStyle(color: p.muted, fontSize: 11.5)),
                      ]),
                    ]),
                  )
                : GlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF5B8DEF).withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.repeat_rounded, color: Color(0xFF5B8DEF))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s.cat(r.$4)?['name'] ?? 'Category'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('Planned · ${'${r.$2['note'] ?? ''}'.isEmpty ? '—' : r.$2['note']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                        ]),
                      ),
                      Text(moneyB(s, r.$5), style: const TextStyle(color: Color(0xFF5B8DEF), fontWeight: FontWeight.w800)),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: p.neg),
                        onPressed: () {
                          s.removePlanned(widget.id, '${r.$2['id']}');
                          toast(context, 'Planned expense removed');
                        },
                      ),
                    ]),
                  ),
          ),
      ]),
    );
  }
}
