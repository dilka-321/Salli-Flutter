import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'categories_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

/// Budget tab: budgets (like the web Budget page) plus shortcuts to Subscriptions, Recurring and Installments.
class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.budgets;
    final tot = L.fold(0.0, (a, b) => a + toD(b['amount']));
    final sp = L.fold(0.0, (a, b) => a + s.budgetSpent(b));
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(
          title: const Text('Budget'),
          actions: [
            IconButton(tooltip: 'Create budget', icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const BudgetEditScreen()))),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            if (L.isEmpty) ...[
              const SizedBox(height: 10),
              const EmptyNote('No budgets yet\nSet daily, weekly, monthly, quarterly or yearly limits for your categories', icon: Icons.savings_outlined),
              Center(
                child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Create Budget'), onPressed: () => Navigator.of(context).push(pageRoute(const BudgetEditScreen()))),
              ),
            ] else ...[
              GlassCard(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(p.accent.withOpacity(.22), p.card), p.card]),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total budgeted', style: TextStyle(color: p.muted)),
                      Text(moneyB(s, tot), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Spent', style: TextStyle(color: p.muted, fontSize: 12)),
                            Text(moneyB(s, sp), style: TextStyle(color: p.neg, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tot - sp >= 0 ? 'Left' : 'Over', style: TextStyle(color: p.muted, fontSize: 12)),
                            Text(moneyB(s, (tot - sp).abs()), style: TextStyle(color: tot - sp >= 0 ? p.pos : p.neg, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ]),
                    ]),
                  ),
                  Ring(tot > 0 ? sp / tot : 0, center: '${(tot > 0 ? sp / tot * 100 : 0).round()}%', color: sp > tot ? p.neg : p.accent),
                ]),
              ),
              const SizedBox(height: 6),
              for (final b in L) Padding(padding: const EdgeInsets.only(top: 12), child: _BudgetCard(b: b)),
            ],
          ]),
        ),
      ]),
    );
  }
}

String _cap(String x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.b});
  final J b;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final amt = toD(b['amount']);
    final sp = s.budgetSpent(b);
    final pc = amt > 0 ? sp / amt : 0.0;
    final (_, e) = periodRange('${b['period'] ?? 'monthly'}');
    final dl = diffDays(today(), e);
    final ids = s.budgetCatIds(b);
    final col = pc >= 1 ? p.neg : pc >= .8 ? p.warn : p.pos;
    return GlassCard(
      onTap: () => Navigator.of(context).push(pageRoute(BudgetViewScreen(id: '${b['id']}'))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(ids.take(3).map((id) => s.cat(id)?['icon'] ?? '').join(), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${ids.length} categor${ids.length == 1 ? 'y' : 'ies'} · $dl day${dl == 1 ? '' : 's'} left', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ]),
          ),
          Badge2(_cap('${b['period'] ?? 'monthly'}'), color: col),
        ]),
        const SizedBox(height: 12),
        ProgressBar(pc),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${moneyB(s, sp)} of ${moneyB(s, amt)}', style: TextStyle(color: p.muted, fontSize: 13))),
          Text(pc >= 1 ? '${moneyB(s, sp - amt)} over' : '${moneyB(s, amt - sp)} left', style: TextStyle(color: pc >= 1 ? p.neg : p.pos, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

/// Budget details: progress, safe daily spend, spending by category and the period's transactions.
class BudgetViewScreen extends StatelessWidget {
  const BudgetViewScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final b = s.budgets.where((x) => x['id'] == id).firstOrNull;
    if (b == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This budget was deleted.'));
    final amt = toD(b['amount']);
    final sp = s.budgetSpent(b);
    final pc = amt > 0 ? sp / amt : 0.0;
    final (f, e) = periodRange('${b['period'] ?? 'monthly'}');
    final list = s.budgetTxns(b);
    final by = <String, double>{};
    for (final t in list) {
      by['${t['catId']}'] = (by['${t['catId']}'] ?? 0) + s.tBase(t);
    }
    final rows = by.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
    final daysLeft = diffDays(today(), e) + 1;
    final safe = (amt - sp) / (daysLeft < 1 ? 1 : daysLeft);
    return Scaffold(
      appBar: AppBar(title: Text('${b['name']}'), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).push(pageRoute(BudgetEditScreen(existing: b)))),
        moreMenu([
          (
            'Delete',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete budget?', 'Delete "${b['name']}"? Your transactions are not affected.')) {
                s.deleteBudget(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Budget deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Column(children: [
            Ring(pc, center: '${(pc * 100).round()}%', size: 130, color: pc >= 1 ? p.neg : pc >= .8 ? p.warn : p.accent),
            const SizedBox(height: 12),
            Text('${fmtDate(f)} – ${fmtDate(e)}', style: TextStyle(color: p.muted)),
            const SizedBox(height: 10),
            kvRow(p, 'Budget', moneyB(s, amt)),
            kvRow(p, 'Spent', moneyB(s, sp), color: p.neg),
            kvRow(p, amt - sp >= 0 ? 'Left' : 'Over', moneyB(s, (amt - sp).abs()), color: amt - sp >= 0 ? p.pos : p.neg, bold: true),
            if (amt - sp > 0) kvRow(p, 'Safe to spend per day', moneyB(s, safe), sub: '$daysLeft day${daysLeft == 1 ? '' : 's'} left incl. today'),
          ]),
        ),
        if (rows.isNotEmpty) ...[
          const SectionTitle('By category'),
          GlassCard(
            child: Column(children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    Row(children: [
                      Text('${s.cat(r.key)?['icon'] ?? '📦'}', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${s.cat(r.key)?['name'] ?? 'Category'}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(moneyB(s, r.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 6),
                    ProgressBar(sp > 0 ? r.value / sp : 0, color: p.accent, height: 6),
                  ]),
                ),
            ]),
          ),
        ],
        const SectionTitle('Transactions'),
        if (list.isEmpty) const EmptyNote('No spending in this period yet.') else TxGroups(list: list, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
}

/// Create / edit a budget: amount, name, period, categories.
class BudgetEditScreen extends StatefulWidget {
  const BudgetEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

class _BudgetEditScreenState extends State<BudgetEditScreen> {
  final amount = TextEditingController();
  final name = TextEditingController();
  String period = 'monthly';
  List<String> catIds = [];
  String? errAmount, errName, errCats;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    if (b != null) {
      amount.text = plainNum(toD(b['amount']));
      name.text = '${b['name'] ?? ''}';
      period = '${b['period'] ?? 'monthly'}';
      catIds = ((b['catIds'] as List?) ?? const []).map((e) => '$e').toList();
    }
  }

  @override
  void dispose() {
    amount.dispose();
    name.dispose();
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    final v = parseAmount(amount.text) ?? 0;
    setState(() {
      errAmount = v > 0 ? null : 'Please enter an amount';
      errName = name.text.trim().isNotEmpty ? null : 'Please enter a name';
      errCats = catIds.isNotEmpty ? null : 'Select at least one category';
    });
    if (errAmount != null || errName != null || errCats != null) return;
    HapticFeedback.lightImpact();
    s.saveBudget(id: widget.existing?['id']?.toString(), name: name.text.trim(), amount: v, period: period, catIds: catIds);
    Navigator.pop(context);
    toast(context, widget.existing != null ? 'Budget updated' : 'Budget created');
  }

  Future<void> _pickCats() async {
    final res = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final sel = [...catIds];
        return StatefulBuilder(builder: (c, set) {
          final s = StoreScope.of(c);
          final p = Palette.of(c);
          final mains = s.categories.where((x) => x['kind'] == 'expense' && x['parent'] == null).toList();
          Widget row(J x, bool sub) => CheckboxListTile(
                contentPadding: EdgeInsets.only(left: sub ? 36 : 4, right: 4),
                value: sel.contains(x['id']),
                onChanged: (v) => set(() {
                  if (v == true) {
                    sel.add('${x['id']}');
                  } else {
                    sel.remove(x['id']);
                  }
                }),
                secondary: Text('${x['icon'] ?? '📦'}', style: const TextStyle(fontSize: 22)),
                title: Text('${x['name']}', style: TextStyle(fontWeight: sub ? FontWeight.w500 : FontWeight.w700)),
                activeColor: p.accent,
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
                  for (final m in mains) ...[
                    row(m, false),
                    for (final sub in s.categories.where((x) => x['parent'] == m['id'])) row(sub, true),
                  ],
                ]),
              ),
            ]),
          );
        });
      },
    );
    if (res != null) setState(() => catIds = res);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Budget' : 'Create Budget')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        AmountBox(controller: amount, currency: s.base, autofocus: widget.existing == null),
        if (errAmount != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(errAmount!, style: TextStyle(color: p.neg))),
        const SizedBox(height: 14),
        TextField(controller: name, decoration: InputDecoration(labelText: 'Budget Name', errorText: errName)),
        const SectionTitle('Budget period'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kBudgetPeriods.entries) ChoiceChip(label: Text(e.value), selected: period == e.key, onSelected: (_) => setState(() => period = e.key)),
        ]),
        SectionTitle('Category', action: 'Create New Category', onAction: () => showCategorySheet(context, kind: 'expense')),
        Text('Choose the categories this budget covers', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 8),
        GlassCard(
          onTap: _pickCats,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Text(catIds.take(3).map((id) => s.cat(id)?['icon'] ?? '').join(), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                catIds.isEmpty ? 'Select categories' : '${catIds.length} categor${catIds.length > 1 ? 'ies' : 'y'}',
                style: TextStyle(color: catIds.isEmpty ? p.muted : null, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ]),
        ),
        if (errCats != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(errCats!, style: TextStyle(color: p.neg))),
        if (catIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final id in catIds) InputChip(label: Text('${s.cat(id)?['icon'] ?? ''} ${s.cat(id)?['name'] ?? 'Deleted'}'), onDeleted: () => setState(() => catIds.remove(id))),
          ]),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: Text(widget.existing != null ? 'Save changes' : 'Create Budget')),
      ]),
    );
  }
}
