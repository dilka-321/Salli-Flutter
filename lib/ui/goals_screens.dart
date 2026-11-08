import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/planning.dart';
import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String tab = 'active';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.goals.where((g) => tab == 'active' ? g['completed'] != true : g['completed'] == true).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton(onPressed: () => showGoalForm(context, null), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'active', label: Text('Active Goals'), icon: Icon(Icons.flag_outlined)),
            ButtonSegment(value: 'done', label: Text('Completed'), icon: Icon(Icons.check_rounded)),
          ],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        if (L.isEmpty) EmptyNote(tab == 'active' ? 'No active goals found. Create a new goal to get started.' : 'No completed goals yet.', icon: Icons.savings_outlined),
        for (final g in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final sv = s.goalSaved(g), tg = toD(g['target']);
              final pc = tg > 0 ? sv / tg : 0.0;
              final ml = s.goalMonthsLeft(g);
              return GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(GoalDetailScreen(id: '${g['id']}'))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    EmojiTile('${g['icon'] ?? '🎯'}', tint: p.pos),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${g['name']}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${g['deadline'] ?? ''}'.isEmpty ? 'No deadline' : 'Target ${fmtDate('${g['deadline']}')}', style: TextStyle(color: p.muted, fontSize: 12.5))])),
                    Text('${(pc * 100).round()}%', style: TextStyle(color: p.pos, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  ProgressBar(pc, color: p.pos),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('${moneyB(s, sv)} of ${moneyB(s, tg)}', style: TextStyle(color: p.muted, fontSize: 12))),
                    if (g['completed'] != true && ml > 0 && pc < 1) Text('${moneyB(s, (tg - sv) / ml)}/month to finish', style: TextStyle(color: p.muted, fontSize: 12)),
                  ]),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

Future<void> showGoalForm(BuildContext context, String? id) {
  final s = StoreScope.read(context);
  final g = id == null ? null : s.goal(id);
  final name = TextEditingController(text: '${g?['name'] ?? ''}');
  final target = TextEditingController(text: g == null ? '' : plainNum(toD(g['target'])));
  final saved = TextEditingController();
  var deadline = '${g?['deadline'] ?? addMonths(today(), 12)}';
  var icon = '${g?['icon'] ?? '🎯'}';
  String? err;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(g != null ? 'Edit Goal' : 'New Saving Goal', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Goal name', hintText: 'e.g. Emergency fund')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Target amount (${s.base})'))),
                const SizedBox(width: 10),
                Expanded(child: DateButton(value: deadline, onChanged: (v) => set(() => deadline = v))),
              ]),
              if (g == null) ...[
                const SizedBox(height: 10),
                TextField(controller: saved, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Already saved (optional)')),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final i in kGoalIcons)
                  GestureDetector(
                    onTap: () => set(() => icon = i),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: icon == i ? p.accent.withOpacity(.2) : p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: icon == i ? p.accent : p.line)),
                      child: Text(i, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ]),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final t = parseAmount(target.text) ?? 0;
                  if (name.text.trim().isEmpty) return set(() => err = 'Enter a goal name.');
                  if (t <= 0) return set(() => err = 'Enter a target amount.');
                  s.saveGoal(id: id, name: name.text.trim(), target: t, deadline: deadline, icon: icon, saved: parseAmount(saved.text) ?? 0);
                  HapticFeedback.lightImpact();
                  Navigator.pop(c);
                  toast(context, 'Goal saved');
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

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _money(BuildContext context, int sign) async {
    final s = StoreScope.read(context);
    final g = s.goal(id)!;
    final amt = TextEditingController();
    String? acc;
    String? err;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final p = Palette.of(c);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${sign > 0 ? 'Add money to' : 'Withdraw from'} ${g['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                AmountBox(controller: amt, currency: s.base, label: 'Amount (${s.base})', autofocus: true),
                const SizedBox(height: 12),
                Text(sign > 0 ? 'TAKE FROM ACCOUNT (OPTIONAL)' : 'RETURN TO ACCOUNT (OPTIONAL)', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                AccountChips(value: acc, allowNone: true, onChanged: (v) => set(() => acc = v)),
                const SizedBox(height: 6),
                Text('Choosing an account moves the money out of (or back into) that account.', style: TextStyle(color: p.muted, fontSize: 12.5)),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final v = parseAmount(amt.text) ?? 0;
                    if (v <= 0) return set(() => err = 'Enter an amount above zero.');
                    if (sign < 0 && v > s.goalSaved(g)) return set(() => err = 'You can withdraw up to ${moneyB(s, s.goalSaved(g))}.');
                    final reached = s.goalMoney(id, v, sign, acc);
                    HapticFeedback.lightImpact();
                    Navigator.pop(c);
                    toast(context, reached ? 'Goal reached! Moved to completed.' : 'Goal updated');
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

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final g = s.goal(id);
    if (g == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This goal was deleted.'));
    final sv = s.goalSaved(g), tg = toD(g['target']);
    final pc = tg > 0 ? sv / tg : 0.0;
    final ml = s.goalMonthsLeft(g);
    final hasD = '${g['deadline'] ?? ''}'.isNotEmpty;
    final cs = s.goalContribs(g).reversed.toList();
    final dl = hasD ? diffDays(today(), '${g['deadline']}') : 0;
    return Scaffold(
      appBar: AppBar(title: Text('${g['name']}'), actions: [
        moreMenu([
          ('Edit goal', Icons.edit_outlined, () => showGoalForm(context, id), false),
          (g['completed'] == true ? 'Mark as active' : 'Mark as completed', Icons.check_rounded, () {
            s.toggleGoal(id);
            toast(context, s.goal(id)?['completed'] == true ? 'Goal completed' : 'Goal reactivated');
          }, false),
          (
            'Delete goal',
            Icons.delete_outline,
            () async {
              if (await confirmDialog(context, 'Delete goal?', 'This cannot be undone.')) {
                s.deleteGoal(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'Goal deleted');
                }
              }
            },
            true
          ),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _money(context, -1), child: const Text('Withdraw'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add Money'), onPressed: () => _money(context, 1))),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.16), p.card), p.card]),
          child: Row(children: [
            Ring(pc, center: '${(pc * 100).round()}%', caption: 'saved', color: p.pos),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Saved', style: TextStyle(color: p.muted)),
                FittedBox(child: Text(moneyB(s, sv), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.pos))),
                Text('of ${moneyB(s, tg)}', style: TextStyle(color: p.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          InfoTile(icon: Icons.flag_outlined, label: 'Remaining', value: moneyB(s, math.max(0.0, tg - sv))),
          InfoTile(icon: Icons.calendar_month_rounded, label: hasD ? 'Needed per month' : 'Deadline', value: hasD ? (pc >= 1 ? 'Done' : moneyB(s, (tg - sv) / ml)) : 'None'),
        ]),
        if (hasD) ...[
          const SizedBox(height: 12),
          GlassCard(child: Row(children: [Icon(Icons.event_rounded, color: p.muted), const SizedBox(width: 10), Expanded(child: Text('Target date ${fmtDate('${g['deadline']}')} · ${dl >= 0 ? '$dl days left' : 'passed'}', style: TextStyle(color: p.muted)))])),
        ],
        const SectionTitle('Contributions'),
        if (cs.isEmpty)
          GlassCard(child: Text('No contributions yet.', style: TextStyle(color: p.muted)))
        else
          GlassCard(
            child: Column(children: [
              for (final c in cs) kvRow(p, fmtDate('${c['date']}'), moneyB(s, toD(c['amount'])), color: toD(c['amount']) < 0 ? p.neg : p.pos, sub: c['accId'] != null ? 'from ${s.accName(c['accId'])}' : null),
            ]),
          ),
      ]),
    );
  }
}

