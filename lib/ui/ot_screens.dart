import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/planning.dart';
import '../core/plans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'widgets.dart';

const _wdL = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _fML(String k) {
  const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final p = k.split('-');
  return '${m[int.parse(p[1]) - 1]} ${p[0]}';
}

Color _stColor(Palette p, String s) => s == 'leave' ? p.warn : s == 'nopay' ? p.neg : s == 'holiday' ? const Color(0xFF5B8DEF) : p.accent;

String _t(String? v) => v == null || v.isEmpty ? '' : fmtTime('$v:00');

/// OT & Salary Tracker — Overview · Daily Log · Pay Preview · Setup (same data as the web app).
class OtScreen extends StatefulWidget {
  const OtScreen({super.key});
  @override
  State<OtScreen> createState() => _OtScreenState();
}

class _OtScreenState extends State<OtScreen> {
  String tab = 'overview';
  String month = ym(today());

  Future<void> _entry(String d) => showOtEntry(context, d);

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final m = s.otMonth(month);
    final c = s.otCfg;
    final months = [for (var i = 0; i < 6; i++) addMonthsYm(ym(today()), -i)];
    if (!months.contains(month)) months.add(month);
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('OT & Salary Tracker'), Text('Est. net: ${moneyB(s, m.net)}', style: TextStyle(color: p.muted, fontSize: 12.5))])),
      floatingActionButton: tab == 'setup' ? null : FloatingActionButton(onPressed: () => _entry(month == ym(today()) ? today() : '$month-01'), child: const Icon(Icons.add_rounded)),
      bottomNavigationBar: tab != 'setup'
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: FilledButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    s.saveOtCfg();
                    HapticFeedback.lightImpact();
                    toast(context, 'Salary settings saved');
                  },
                  child: const Text('Save Settings'),
                ),
              ),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'overview', label: Text('Overview')),
              ButtonSegment(value: 'log', label: Text('Daily Log')),
              ButtonSegment(value: 'pay', label: Text('Pay Preview')),
              ButtonSegment(value: 'setup', label: Text('Setup')),
            ],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
        ),
        const SizedBox(height: 12),
        if (tab != 'setup')
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final k in months) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(fmtMonth(k)), selected: month == k, onSelected: (_) => setState(() => month = k))),
            ]),
          ),
        const SizedBox(height: 8),
        ...(switch (tab) {
          'overview' => _overview(s, p, m, c),
          'log' => _log(s, p, m),
          'pay' => _pay(s, p, m, c),
          _ => <Widget>[OtSetup(key: ValueKey(s.otCfg.hashCode))],
        }),
      ]),
    );
  }

  List<Widget> _overview(AppStore s, Palette p, OtMonth m, J c) {
    final te = s.otEntry(today());
    return [
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fML(month), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('${m.ent.length} of ${m.n} days logged · ${m.n - m.ent.length} unlogged', style: TextStyle(color: p.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(children: [Text('${m.cnt['worked']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text('Days worked', style: TextStyle(color: p.muted, fontSize: 12))])),
            Container(width: 1, height: 44, color: p.line),
            Expanded(child: Column(children: [Text('${m.ot.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text('OT hours', style: TextStyle(color: p.muted, fontSize: 12))])),
          ]),
        ]),
      ),
      if (month == ym(today())) ...[
        const SizedBox(height: 12),
        GlassCard(
          onTap: () => _entry(today()),
          child: Column(children: [
            Row(children: [
              Text('TODAY ', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800)),
              Text('${weekday(today())} ${parseDate(today()).day}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (te != null) Badge2('● ${kOtStatus[te['status']] ?? 'Worked'}', color: p.pos),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(te != null && '${te['in'] ?? ''}'.isNotEmpty ? '${_t(te['in']?.toString())} – ${_t(te['out']?.toString())}' : 'No times set', style: TextStyle(color: p.muted))),
              Text('Tap to log', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('Missing days', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 8), Badge2('${m.missing.length}', color: p.warn)]),
          const SizedBox(height: 6),
          if (m.missing.isEmpty) Text('All days so far are logged.', style: TextStyle(color: p.muted, fontSize: 13)),
          for (final d in m.missing)
            InkWell(
              onTap: () => _entry(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 28, child: Text('${parseDate(d).day}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(weekday(d), style: TextStyle(color: p.muted, fontSize: 13)),
                  const Spacer(),
                  Text('Not logged ', style: TextStyle(color: p.muted, fontSize: 13)),
                  Icon(Icons.add_rounded, color: p.pos, size: 20),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Day breakdown', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                if (m.ent.isEmpty) Expanded(child: Container(color: p.fg.withOpacity(.08))),
                for (final e in kOtStatus.keys)
                  if ((m.cnt[e] ?? 0) > 0) Expanded(flex: m.cnt[e]!, child: Container(color: _stColor(p, e))),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          for (final e in kOtStatus.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: _stColor(p, e.key), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value)),
                Text('${m.cnt[e.key] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hours', style: TextStyle(fontWeight: FontWeight.w800)),
          kvRow(p, 'Total worked hours', '${m.worked.toStringAsFixed(1)}h'),
          kvRow(p, 'Total OT hours', '${m.ot.toStringAsFixed(1)}h'),
          kvRow(p, 'Avg per worked day', '${((m.cnt['worked'] ?? 0) > 0 ? m.worked / m.cnt['worked']! : 0).toStringAsFixed(1)}h'),
          kvRow(p, 'Standard day', '${plainNum(toD(c['stdHours']))}h'),
        ]),
      ),
    ];
  }

  List<Widget> _log(AppStore s, Palette p, OtMonth m) {
    final L = m.days.where((d) => s.otEntry(d) != null).toList().reversed.toList();
    if (L.isEmpty) return const [EmptyNote('No entries this month\nTap + to log a day', icon: Icons.schedule_rounded)];
    return [
      for (final d in L)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Builder(builder: (_) {
            final e = s.otEntry(d)!;
            final st = '${e['status'] ?? 'worked'}';
            return GlassCard(
              onTap: () => _entry(d),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: p.pos.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Text('${parseDate(d).day}', style: TextStyle(color: p.pos, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_wdL[parseDate(d).weekday - 1], style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${'${e['in'] ?? ''}'.isNotEmpty ? '${_t(e['in']?.toString())} – ${_t(e['out']?.toString())}' : 'No times'} · OT ${toD(e['ot']).toStringAsFixed(1)}h', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ]),
                ),
                Badge2('● ${kOtStatus[st] ?? st}', color: _stColor(p, st)),
              ]),
            );
          }),
        ),
    ];
  }

  List<Widget> _pay(AppStore s, Palette p, OtMonth m, J c) {
    Widget row(String l, double v, {Color? col}) => kvRow(p, l, moneyB(s, v), color: col);
    final epfRate = toD(c['epf']);
    return [
      GlassCard(
        gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.2), p.card), p.card]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimated net pay · ${_fML(month)}', style: TextStyle(color: p.muted)),
          Text(moneyB(s, m.net), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.pos)),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800)),
          row('Basic salary', toD(c['basic'])),
          for (final x in m.allow) row('${x['name'] ?? ''}'.isEmpty ? 'Allowance' : '${x['name']}', toD(x['amount'])),
          row('OT pay (${m.ot.toStringAsFixed(1)}h × ${moneyB(s, m.otRate)})', m.otPay, col: p.pos),
          if (m.nopay != 0) row('No-pay deduction (${m.cnt['nopay']} days)', -m.nopay, col: p.neg),
          kvRow(p, 'Gross pay', moneyB(s, m.gross), bold: true),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Deductions', style: TextStyle(fontWeight: FontWeight.w800)),
          row('EPF employee (${plainNum(epfRate)}%)', -m.epf, col: p.neg),
          for (final x in m.ded) row('${x['name'] ?? ''}'.isEmpty ? 'Deduction' : '${x['name']}', -toD(x['amount']), col: p.neg),
          kvRow(p, 'Total deductions', moneyB(s, -(m.epf + m.dedSum)), color: p.neg, bold: true),
        ]),
      ),
      const SizedBox(height: 12),
      GlassCard(
        child: Text(
          'Employer contributions (not deducted from your net): EPF ${epfRate != 0 ? 12 : 0}% ≈ ${moneyB(s, m.epf / (epfRate != 0 ? epfRate : 1) * 12)}, ETF ${plainNum(toD(c['etf']))}% ≈ ${moneyB(s, m.etf)}.',
          style: TextStyle(color: p.muted, fontSize: 13),
        ),
      ),
    ];
  }
}

/// Setup tab: edits the salary settings in place (saved with "Save Settings").
class OtSetup extends StatefulWidget {
  const OtSetup({super.key});
  @override
  State<OtSetup> createState() => _OtSetupState();
}

class _OtSetupState extends State<OtSetup> {
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final c = s.otCfg;
    final allow = (c['allowances'] as List).whereType<Map>().toList();
    final ded = (c['deductions'] as List).whereType<Map>().toList();
    Widget numRow(String l, String k, {String? sub}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l), if (sub != null) Text(sub, style: TextStyle(color: p.muted, fontSize: 12))])),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: plainNum(toD(c[k])),
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.w700),
                onChanged: (v) => c[k] = double.tryParse(v.trim()) ?? 0,
              ),
            ),
          ]),
        );
    Widget listCard(Map x, int i, String k, bool epf) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${x['name'] ?? ''}',
                    decoration: InputDecoration(hintText: epf ? 'Allowance name' : 'Deduction name', filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                    onChanged: (v) => x['name'] = v,
                  ),
                ),
                IconButton(onPressed: () => setState(() => (c[k] as List).removeAt(i)), icon: Icon(Icons.delete_outline, color: p.neg)),
              ]),
              Row(children: [
                Text('Amount', style: TextStyle(color: p.muted, fontSize: 13)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: plainNum(toD(x['amount'])),
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => x['amount'] = double.tryParse(v.trim()) ?? 0,
                  ),
                ),
                if (epf) ...[
                  const SizedBox(width: 8),
                  Text('EPF eligible', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  Checkbox(value: x['epf'] == true, onChanged: (v) => setState(() => x['epf'] = v == true)),
                ],
              ]),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassCard(
        child: Column(children: [
          numRow('Basic salary', 'basic'),
          numRow('OT rate (per hour)', 'otRate', sub: 'Leave 0 to use 1.5× hourly basic'),
          numRow('Working days / month', 'workDays'),
          numRow('Standard hours / day', 'stdHours'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-OT'),
            subtitle: const Text('Calculate OT from daily attendance'),
            value: c['autoOT'] == true,
            onChanged: (v) => setState(() => c['autoOT'] = v),
          ),
        ]),
      ),
      const SectionTitle('EPF / ETF'),
      GlassCard(
        child: Column(children: [
          numRow('EPF employee rate (%)', 'epf'),
          numRow('ETF rate (%)', 'etf', sub: 'Employer-paid — for reference only, not deducted from your net'),
        ]),
      ),
      SectionTitle('Allowances', action: '+ Add', onAction: () => setState(() => (c['allowances'] as List).add(<String, dynamic>{'name': '', 'amount': 0, 'epf': false}))),
      for (var i = 0; i < allow.length; i++) listCard(allow[i], i, 'allowances', true),
      SectionTitle('Other Deductions', action: '+ Add', onAction: () => setState(() => (c['deductions'] as List).add(<String, dynamic>{'name': '', 'amount': 0}))),
      for (var i = 0; i < ded.length; i++) listCard(ded[i], i, 'deductions', false),
    ]);
  }
}

/// Add / edit one day's attendance.
Future<void> showOtEntry(BuildContext context, String d0) {
  final s = StoreScope.read(context);
  final e = s.otEntry(d0);
  var d = d0;
  var orig = d0;
  var inT = '${e?['in'] ?? ''}';
  var outT = '${e?['out'] ?? ''}';
  var status = '${e?['status'] ?? 'worked'}';
  final otCtl = TextEditingController(text: e == null || '${e['ot'] ?? ''}'.isEmpty ? '' : plainNum(toD(e['ot'])));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      final exists = s.otEntry(orig) != null;
      final auto = s.otCfg['autoOT'] == true && inT.isNotEmpty && outT.isNotEmpty ? s.otAuto(inT, outT) : null;
      final k = ym(d);
      Future<void> pickTime(bool isIn) async {
        final cur = isIn ? inT : outT;
        final parts = cur.split(':');
        final t = await showTimePicker(context: c, initialTime: cur.isEmpty ? TimeOfDay(hour: isIn ? 8 : 17, minute: 0) : TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0));
        if (t == null) return;
        final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        set(() {
          if (isIn) {
            inT = v;
          } else {
            outT = v;
          }
        });
      }

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(exists ? 'Edit entry' : 'Add entry', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                IconButton(onPressed: () => set(() => d = '${addMonthsYm(k, -1)}-01'), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Center(child: Text(_fML(k), style: const TextStyle(fontWeight: FontWeight.w800)))),
                IconButton(onPressed: () => set(() => d = '${addMonthsYm(k, 1)}-01'), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              DropdownButtonFormField<String>(
                key: ValueKey(k),
                initialValue: d,
                decoration: const InputDecoration(labelText: 'Day'),
                items: [
                  for (var i = 1; i <= daysIn(k); i++)
                    DropdownMenuItem(value: '$k-${i.toString().padLeft(2, '0')}', child: Text('$i (${weekday('$k-${i.toString().padLeft(2, '0')}')})')),
                ],
                onChanged: (v) => set(() {
                  if (v == null) return;
                  d = v;
                  final x = s.otEntry(v);
                  if (x != null) {
                    orig = v;
                    inT = '${x['in'] ?? ''}';
                    outT = '${x['out'] ?? ''}';
                    status = '${x['status'] ?? 'worked'}';
                    otCtl.text = '${x['ot'] ?? ''}'.isEmpty ? '' : plainNum(toD(x['ot']));
                  }
                }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.login_rounded, size: 18), label: Text(inT.isEmpty ? 'In time' : 'In ${_t(inT)}'), onPressed: () => pickTime(true))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.logout_rounded, size: 18), label: Text(outT.isEmpty ? 'Out time' : 'Out ${_t(outT)}'), onPressed: () => pickTime(false))),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: otCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'OT hours${auto != null ? ' · auto ${auto.toStringAsFixed(2)}h' : ''}', hintText: '0.00'),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final st in kOtStatus.entries) ChoiceChip(label: Text('● ${st.value}'), selected: status == st.key, selectedColor: _stColor(p, st.key).withOpacity(.25), onSelected: (_) => set(() => status = st.key)),
              ]),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  s.saveOtEntry(orig: orig, date: d, inT: inT, outT: outT, otText: otCtl.text, status: status);
                  HapticFeedback.lightImpact();
                  Navigator.pop(c);
                  toast(context, 'Entry saved');
                },
                child: const Text('Save'),
              ),
              if (exists)
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, color: p.neg),
                  label: Text('Delete entry', style: TextStyle(color: p.neg)),
                  onPressed: () {
                    s.deleteOtEntry(orig);
                    Navigator.pop(c);
                    toast(context, 'Entry deleted');
                  },
                ),
            ]),
          ),
        ),
      );
    }),
  );
}
