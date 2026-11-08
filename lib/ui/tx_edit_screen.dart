import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/planning.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'categories_screen.dart';
import 'productivity_screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// Add or edit a plain income / expense (same fields and saved shape as the web app).
class TxEditScreen extends StatefulWidget {
  const TxEditScreen({super.key, required this.type, this.existing, this.planId, this.presetCatId, this.presetDate, this.draft});
  final String type;
  final J? existing;

  /// spending plan to link a new expense to (from a spending plan's "Add Transaction")
  final String? planId;
  final String? presetCatId;

  /// prefilled values for a new transaction (e.g. from an SMS draft)
  final J? draft;
  final String? presetDate;
  @override
  State<TxEditScreen> createState() => _TxEditScreenState();
}

class _TxEditScreenState extends State<TxEditScreen> {
  late String type;
  final amount = TextEditingController();
  final note = TextEditingController();
  String? catId, accId, planId;
  List<String> tags = [];
  late String date;
  late String time;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    type = widget.type == 'income' ? 'income' : 'expense';
    date = (e?['date'] ?? widget.presetDate ?? today()).toString();
    planId = e != null ? e['planId']?.toString() : widget.planId;
    catId = widget.presetCatId;
    tags = ((e?['tags'] as List?) ?? const []).map((x) => '$x').toList();
    time = (e?['time'] ?? nowTime()).toString();
    final d = widget.draft;
    if (e == null && d != null) {
      final a = toD(d['amount']);
      if (a > 0) amount.text = a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString();
      note.text = (d['note'] ?? '').toString();
      catId = d['catId']?.toString();
      accId = d['accId']?.toString();
      date = (d['date'] ?? date).toString();
    }
    if (e != null) {
      final a = toD(e['amount']);
      amount.text = a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString();
      note.text = (e['note'] ?? '').toString();
      catId = e['catId']?.toString();
      accId = e['accId']?.toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    accId ??= StoreScope.read(context).defaultAccId;
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void save() {
    final s = StoreScope.read(context);
    final v = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
    if (v <= 0) return toast(context, 'Enter an amount above zero');
    if (catId == null) return toast(context, 'Choose a category');
    if (accId == null) return toast(context, 'Choose an account');
    final e = widget.existing;
    final rec = <String, dynamic>{
      'id': e?['id'] ?? uid(),
      'type': type,
      'kind': e?['kind'] ?? 'normal',
      'catId': catId,
      'accId': accId,
      'amount': round2(v),
      'date': date,
      'time': time,
      'note': note.text.trim(),
      'tags': <dynamic>[...tags],
      if (e == null) 'receipt': null,
      'planId': type == 'expense' ? planId : null,
    };
    HapticFeedback.lightImpact();
    s.saveTx(rec);
    Navigator.pop(context);
    toast(context, 'Successfully saved transaction');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final inc = type == 'income';
    final cur = s.accCur(accId);
    final cats = s.categories.where((c) => c['kind'] == type).toList();
    // most recently used first
    final used = <String>[];
    for (final t in s.txns.reversed) {
      final id = t['catId']?.toString();
      if (t['type'] == type && id != null && !used.contains(id)) used.add(id);
      if (used.length >= 40) break;
    }
    cats.sort((a, b) {
      final ia = used.indexOf('${a['id']}'), ib = used.indexOf('${b['id']}');
      return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
    });
    final head = inc ? p.pos : p.accent;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.existing == null ? 'Add' : 'Edit'} ${inc ? 'Income' : 'Expense'}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (widget.existing == null)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense'), icon: Icon(Icons.south_west_rounded)),
              ButtonSegment(value: 'income', label: Text('Income'), icon: Icon(Icons.north_east_rounded)),
            ],
            selected: {type},
            onSelectionChanged: (v) => setState(() {
              type = v.first;
              catId = null;
            }),
          ),
        const SizedBox(height: 14),
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(head.withOpacity(.22), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Amount', style: TextStyle(color: p.muted)),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(currencySymbol(cur), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.muted)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: amount,
                  autofocus: widget.existing == null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: '0.00', contentPadding: EdgeInsets.zero),
                ),
              ),
            ]),
          ]),
        ),
        const SectionTitle('Category'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in cats)
            _CatChip(
              icon: '${c['icon'] ?? '📦'}',
              name: '${c['name']}',
              on: catId == c['id'],
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => catId = '${c['id']}');
              },
            ),
          ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('New'), onPressed: () => showCategorySheet(context, kind: type)),
        ]),
        const SectionTitle('Account'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in s.accounts)
            ChoiceChip(
              label: Text('${a['name']} · ${a['currency']}'),
              avatar: Icon(s.isCard(a) ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined, size: 18),
              selected: accId == a['id'],
              onSelected: (_) => setState(() => accId = '${a['id']}'),
            ),
        ]),
        const SectionTitle('Date & time'),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(fmtDate(date)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: parseDate(date), firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => date = isoDate(d));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(fmtTime(time)),
              onPressed: () async {
                final parts = time.split(':');
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0));
                if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00');
              },
            ),
          ),
        ]),
        if (type == 'expense' && s.splans.isNotEmpty) ...[
          const SectionTitle('Spending plan'),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            onTap: () async {
              final x = await _pickPlan(context, planId);
              if (x != null) setState(() => planId = x.isEmpty ? null : x);
            },
            child: Row(children: [
              Icon(Icons.calendar_month_rounded, color: p.pos),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SPENDING PLAN', style: TextStyle(color: p.pos, fontSize: 11, fontWeight: FontWeight.w800)),
                  Text(s.splan(planId ?? '')?['name']?.toString() ?? 'Select a spending plan', style: TextStyle(fontWeight: planId != null ? FontWeight.w700 : FontWeight.w400, color: planId != null ? null : p.muted)),
                ]),
              ),
              if (planId != null) IconButton(onPressed: () => setState(() => planId = null), icon: Icon(Icons.close_rounded, color: p.neg)) else Icon(Icons.chevron_right_rounded, color: p.muted),
            ]),
          ),
        ],
        SectionTitle('Tags', action: '+ Add tag', onAction: () => showTagDialog(context, null)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in s.tags)
            FilterChip(
              label: Text('${t['name']}'),
              selected: tags.contains(t['name']),
              onSelected: (v) => setState(() {
                if (v) {
                  tags.add('${t['name']}');
                } else {
                  tags.remove(t['name']);
                }
              }),
            ),
          if (s.tags.isEmpty) Text('No tags yet', style: TextStyle(color: p.muted, fontSize: 13)),
        ]),
        const SectionTitle('Note'),
        TextField(controller: note, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'Add a note')),
        const SizedBox(height: 22),
        FilledButton(onPressed: save, child: const Text('Save')),
      ]),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.icon, required this.name, required this.on, required this.onTap});
  final String icon, name;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? p.accent.withOpacity(.18) : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? p.accent : p.line, width: on ? 1.6 : 1),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Spending plan picker (active plans first) — returns the id, '' for none, or null when cancelled.
Future<String?> _pickPlan(BuildContext context, String? current) {
  final s = StoreScope.read(context);
  final L = [...s.splans]..sort((a, b) {
      final x = (s.splanActive(b) ? 1 : 0) - (s.splanActive(a) ? 1 : 0);
      return x != 0 ? x : '${b['start']}'.compareTo('${a['start']}');
    });
  return showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Select a spending plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        ListTile(leading: const Icon(Icons.block_rounded), title: const Text('None'), onTap: () => Navigator.pop(c, '')),
        for (final pl in L)
          ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text('${pl['name']}'),
            subtitle: Text(s.splanActive(pl) ? 'Active' : fmtDate('${pl['start']}')),
            trailing: current == pl['id'] ? const Icon(Icons.check_circle_rounded) : null,
            onTap: () => Navigator.pop(c, '${pl['id']}'),
          ),
      ]),
    ),
  );
}
