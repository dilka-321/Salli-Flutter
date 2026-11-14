import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'widgets.dart';

/// Home → Net Cash Flow card: breakdown sheet.
void showNetCashFlowSheet(BuildContext context) {
  final s = StoreScope.read(context);
  final mk = ym(today());
  final st = s.stats(monthStart(mk), monthEnd(mk));
  final net = st.cin - st.cout;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final p = Palette.of(c);
      Widget row(String l, double v, Color col, {bool bold = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 15 : 14))),
              Text(money(v, s.base), style: TextStyle(color: col, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 15 : 14)),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Net Cash Flow', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Includes money received from loans. Excludes wallet transfers.', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 14),
            row('Cash In', st.cin, p.pos),
            row('Cash Out', st.cout, p.neg),
            Divider(color: p.line, height: 20),
            row('Net Cash Flow', net, net < 0 ? p.neg : p.pos, bold: true),
          ]),
        ),
      );
    },
  );
}

/// Filters for the cash-flow transactions page.
class CashFilter {
  CashFilter({required this.mode, this.allTime = false, required this.month, this.name = '', this.amount = '', Set<String>? cats}) : cats = cats ?? <String>{};
  String mode; // all | income | expense | cashin | cashout
  bool allTime;
  String month; // yyyy-mm
  String name, amount;
  Set<String> cats;

  CashFilter copy() => CashFilter(mode: mode, allTime: allTime, month: month, name: name, amount: amount, cats: {...cats});

  /// Number of active filters (shown on the Filters badge and the Apply button).
  int get count => (allTime ? 0 : 1) + (mode == 'all' ? 0 : 1) + (name.trim().isEmpty ? 0 : 1) + (amount.trim().isEmpty ? 0 : 1) + (cats.isEmpty ? 0 : 1);

  static const modes = [('all', 'All'), ('income', 'Income'), ('expense', 'Expense'), ('cashin', 'Cash In'), ('cashout', 'Cash Out')];
  String get title => switch (mode) {
        'income' => 'Income Transactions',
        'expense' => 'Expense Transactions',
        'cashin' => 'Cash In Transactions',
        'cashout' => 'Cash Out Transactions',
        _ => 'All Transactions',
      };
}

/// Cash In / Cash Out (or Income / Expense / All) transactions with a Filters sheet.
class CashFlowTxnsScreen extends StatefulWidget {
  const CashFlowTxnsScreen({super.key, required this.mode});
  final String mode;
  @override
  State<CashFlowTxnsScreen> createState() => _CashFlowTxnsScreenState();
}

class _CashFlowTxnsScreenState extends State<CashFlowTxnsScreen> {
  late CashFilter f = CashFilter(mode: widget.mode, month: ym(today()));

  bool _modeOk(AppStore s, J t) => switch (f.mode) {
        'income' => s.isInc(t),
        'expense' => s.isExp(t),
        'cashin' => s.isCashIn(t),
        'cashout' => s.isCashOut(t),
        _ => true,
      };

  List<J> _list(AppStore s) {
    final q = f.name.trim().toLowerCase();
    final amt = double.tryParse(f.amount.replaceAll(',', '').trim());
    // a chosen main category also matches its subcategories
    final cats = <String>{...f.cats};
    for (final c in s.categories) {
      if (f.cats.contains('${c['parent']}')) cats.add('${c['id']}');
    }
    return s.txns.where((t) {
      final d = '${t['date'] ?? ''}';
      if (!f.allTime && (d.compareTo(monthStart(f.month)) < 0 || d.compareTo(monthEnd(f.month)) > 0)) return false;
      if (f.mode == 'cashin' || f.mode == 'cashout' || f.mode == 'income' || f.mode == 'expense') {
        final a = s.acc(t['accId']);
        if (!(a?['include'] != false || a?['type'] == 'credit')) return false; // same as the Home totals
      }
      if (!_modeOk(s, t)) return false;
      if (q.isNotEmpty && !'${s.txTitle(t)} ${t['note'] ?? ''} ${t['who'] ?? ''}'.toLowerCase().contains(q)) return false;
      if (amt != null && (toD(t['amount']) - amt).abs() > 0.005 && (s.tBase(t) - amt).abs() > 0.005) return false;
      if (cats.isNotEmpty && !cats.contains('${t['catId']}')) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final list = _list(s);
    return Scaffold(
      appBar: AppBar(title: Text(f.title), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: TextButton.icon(
            onPressed: () async {
              final r = await showCashFilterSheet(context, f);
              if (r != null) setState(() => f = r);
            },
            icon: Badge(
              isLabelVisible: f.count > 0,
              label: Text('${f.count}'),
              backgroundColor: p.neg,
              child: Icon(Icons.tune_rounded, color: p.fg),
            ),
            label: Text('Filters', style: TextStyle(color: p.fg)),
          ),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (list.isEmpty) const EmptyNote('No transactions match these filters.') else TxGroups(list: list, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
}

Future<CashFilter?> showCashFilterSheet(BuildContext context, CashFilter start) {
  final f = start.copy();
  final nameCtl = TextEditingController(text: f.name);
  final amtCtl = TextEditingController(text: f.amount);
  var catQ = '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return showModalBottomSheet<CashFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final s = StoreScope.of(c);
      final p = Palette.of(c);
      final kind = f.mode == 'income' || f.mode == 'cashin'
          ? 'income'
          : f.mode == 'expense' || f.mode == 'cashout'
              ? 'expense'
              : null;
      final cats = s.categories.where((x) => (kind == null || x['kind'] == kind) && (catQ.isEmpty || '${x['name']}'.toLowerCase().contains(catQ))).toList()
        ..sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
      final y = int.parse(f.month.substring(0, 4)), m = int.parse(f.month.substring(5, 7));
      final nowY = DateTime.now().year;
      final years = [for (var i = nowY + 1; i >= nowY - 10; i--) i];
      Widget label(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 16, 2, 8), child: Text(t, style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)));
      Widget chip(String t, bool on, VoidCallback tap) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                tap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? p.accent : p.fg.withOpacity(.05),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: on ? p.accent : p.line),
                ),
                child: Text(t, style: TextStyle(color: on ? p.accentInk : p.fg.withOpacity(.85), fontSize: 12.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
              ),
            ),
          );
      Widget dd<T>(String lab, T value, List<(T, String)> items, ValueChanged<T> on) => Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: lab, isDense: true),
              items: [for (final it in items) DropdownMenuItem(value: it.$1, child: Text(it.$2))],
              onChanged: (v) {
                if (v != null) on(v);
              },
            ),
          );
      f.name = nameCtl.text;
      f.amount = amtCtl.text;
      final n = f.count;
      return SizedBox(
        height: MediaQuery.of(c).size.height * .86,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
              child: Row(children: [
                const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                if (n > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(99)),
                    child: Text('$n', style: TextStyle(color: p.accentInk, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => set(() {
                    f.allTime = true;
                    f.mode = 'all';
                    f.cats.clear();
                    nameCtl.clear();
                    amtCtl.clear();
                    catQ = '';
                  }),
                  child: const Text('Clear Filters'),
                ),
                IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12), children: [
                label('DATE RANGE'),
                Wrap(children: [chip('All time', f.allTime, () => set(() => f.allTime = true)), chip('Date Range', !f.allTime, () => set(() => f.allTime = false))]),
                if (!f.allTime)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      dd<int>('Select month', m, [for (var i = 1; i <= 12; i++) (i, months[i - 1])], (v) => set(() => f.month = '$y-${v.toString().padLeft(2, '0')}')),
                      const SizedBox(width: 10),
                      dd<int>('Select year', years.contains(y) ? y : nowY, [for (final yy in years) (yy, '$yy')], (v) => set(() => f.month = '$v-${m.toString().padLeft(2, '0')}')),
                    ]),
                  ),
                label('SELECT MODE'),
                Wrap(children: [
                  for (final md in CashFilter.modes)
                    chip(md.$2, f.mode == md.$1, () => set(() {
                          f.mode = md.$1;
                          f.cats.clear(); // categories are per income / expense
                        })),
                ]),
                label('FILTER BY NAME'),
                TextField(
                  controller: nameCtl,
                  onChanged: (_) => set(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search transaction name',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: nameCtl.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => set(nameCtl.clear)),
                  ),
                ),
                label('FILTER BY AMOUNT'),
                TextField(
                  controller: amtCtl,
                  onChanged: (_) => set(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    suffixIcon: amtCtl.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => set(amtCtl.clear)),
                  ),
                ),
                label('FILTER BY CATEGORIES'),
                TextField(onChanged: (v) => set(() => catQ = v.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Search categories', prefixIcon: Icon(Icons.search_rounded))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
                  decoration: BoxDecoration(color: p.fg.withOpacity(.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
                  child: Wrap(children: [
                    chip('All Categories', f.cats.isEmpty, () => set(f.cats.clear)),
                    for (final x in cats)
                      chip('${x['icon'] ?? ''} ${x['name']}'.trim(), f.cats.contains('${x['id']}'), () => set(() {
                            final id = '${x['id']}';
                            if (f.cats.contains(id)) {
                              f.cats.remove(id);
                            } else {
                              f.cats.add(id);
                            }
                          })),
                  ]),
                ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: FilledButton(
                  onPressed: () {
                    f.name = nameCtl.text;
                    f.amount = amtCtl.text;
                    Navigator.pop(c, f);
                  },
                  child: Text(n > 0 ? 'Apply ($n)' : 'Apply'),
                ),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}
