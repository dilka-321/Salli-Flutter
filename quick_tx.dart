import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../core/currency.dart';
import '../core/planning.dart';
import '../core/round6.dart';
import '../core/round7.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'productivity_screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// Add a new income / expense in three steps, like the Salli web app:
/// 1) Select Category → 2) Select Account + calculator (Quick Save / Add More Details) →
/// 3) Add Note, Tags, Receipt, or Date → Save.
class QuickTxScreen extends StatefulWidget {
  const QuickTxScreen({super.key, required this.type, this.accId});
  final String type;

  /// account to start with (e.g. the account page's + button)
  final String? accId;
  @override
  State<QuickTxScreen> createState() => _QuickTxScreenState();
}

class _QuickTxScreenState extends State<QuickTxScreen> {
  int step = 0; // 0 category, 1 amount, 2 details
  bool back = false; // animation direction
  String? catId, accId, planId, receipt;
  String expr = '';
  late String date, time;
  final tags = <String>[];
  final note = TextEditingController();
  final rate = TextEditingController();
  final search = TextEditingController();
  double amount = 0;
  bool _init = false;

  String get type => widget.type == 'income' ? 'income' : 'expense';
  bool get inc => type == 'income';

  @override
  void initState() {
    super.initState();
    date = today();
    time = nowTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    accId = widget.accId != null && s.acc(widget.accId) != null ? widget.accId : s.defaultAccId;
  }

  @override
  void dispose() {
    note.dispose();
    rate.dispose();
    search.dispose();
    super.dispose();
  }

  void _go(int to) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      back = to < step;
      step = to;
    });
  }

  void _back() {
    if (step > 0) {
      _go(step - 1);
    } else {
      Navigator.pop(context);
    }
  }

  // ------------------------------------------------------------------ calculator
  static double evalExpr(String expr) {
    final s = expr.replaceAll('×', '*').replaceAll('÷', '/');
    if (s.isEmpty || !RegExp(r'^[\d.+\-*/\s]*$').hasMatch(s)) return 0;
    try {
      final toks = RegExp(r'\d*\.?\d+|[+\-*/]').allMatches(s).map((m) => m.group(0)!).toList();
      final out = <double>[], ops = <String>[];
      const pr = {'+': 1, '-': 1, '*': 2, '/': 2};
      void ap() {
        final b = out.isEmpty ? 0.0 : out.removeLast();
        final a = out.isEmpty ? 0.0 : out.removeLast();
        final o = ops.removeLast();
        out.add(o == '+'
            ? a + b
            : o == '-'
                ? a - b
                : o == '*'
                    ? a * b
                    : (b != 0 ? a / b : 0));
      }

      var prevOp = true;
      for (final t in toks) {
        if (pr.containsKey(t)) {
          if (prevOp) {
            if (t == '-') {
              out.add(0);
              ops.add('-');
            }
            continue;
          }
          while (ops.isNotEmpty && pr[ops.last]! >= pr[t]!) {
            ap();
          }
          ops.add(t);
          prevOp = true;
        } else {
          out.add(double.parse(t));
          prevOp = false;
        }
      }
      if (prevOp && ops.isNotEmpty) ops.removeLast();
      while (ops.isNotEmpty) {
        ap();
      }
      return round2(out.isEmpty ? 0 : out.first);
    } catch (_) {
      return 0;
    }
  }

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');

  void _key(String k) {
    HapticFeedback.selectionClick();
    var e = expr;
    final last = e.split(RegExp(r'[÷×\-+]')).last;
    if (k == 'C') {
      e = '';
    } else if (k == '⌫') {
      if (e.isNotEmpty) e = e.substring(0, e.length - 1);
    } else if (k == '=') {
      final v = evalExpr(e);
      e = v == 0 ? '' : _fmtNum(v);
    } else if ('÷×-+'.contains(k)) {
      if (e.isEmpty && k != '-') return;
      if (RegExp(r'[÷×\-+]$').hasMatch(e)) e = e.substring(0, e.length - 1);
      e += k;
    } else if (k == '.') {
      if (last.contains('.')) return;
      e += last.isEmpty ? '0.' : '.';
    } else {
      if (last == '0') e = e.substring(0, e.length - 1);
      if (last.contains('.') && last.split('.')[1].length >= 2) return;
      if (last.replaceAll('.', '').length >= 12) return;
      e += k;
    }
    setState(() => expr = e);
  }

  // ------------------------------------------------------------------ save
  bool _checkAmount() {
    final v = evalExpr(expr);
    if (v <= 0) {
      toast(context, 'Enter an amount above zero');
      return false;
    }
    if (accId == null) {
      toast(context, 'Choose an account');
      return false;
    }
    amount = v;
    return true;
  }

  void _save() {
    final s = StoreScope.read(context);
    if (catId == null) return toast(context, 'Choose a category');
    if (amount <= 0 && !_checkAmount()) return;
    final cur = s.accCur(accId);
    final r = double.tryParse(rate.text.replaceAll(',', '').trim());
    if (cur != s.base && r != null && r > 0) s.saveRate(null, cur, s.base, r);
    final rec = <String, dynamic>{
      'id': uid(),
      'type': type,
      'kind': 'normal',
      'catId': catId,
      'accId': accId,
      'amount': round2(amount),
      'date': date,
      'time': time,
      'note': note.text.trim(),
      'tags': <dynamic>[...tags],
      'receipt': receipt,
      'planId': type == 'expense' ? planId : null,
    };
    HapticFeedback.lightImpact();
    s.saveTx(rec);
    Navigator.pop(context);
    toast(context, 'Successfully saved transaction');
  }

  // ------------------------------------------------------------------ UI
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final top = Color.lerp(p.accent, Colors.black, .45)!;
    final Widget body = switch (step) {
      0 => _categoryStep(context),
      1 => _amountStep(context),
      _ => _detailsStep(context),
    };
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: top,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
          title: Text(inc ? 'Add Income' : 'Add Expense', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: Container(
          margin: EdgeInsets.only(top: step == 0 ? 0 : 22),
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 24, offset: const Offset(0, -4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 6), width: 40, height: 4, decoration: BoxDecoration(color: p.muted.withOpacity(.45), borderRadius: BorderRadius.circular(9))),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, a) {
                  final isIn = child.key == ValueKey(step);
                  final dx = (isIn ? 1 : -1) * (back ? -1 : 1) * .18;
                  return FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(step), child: body),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _secLabel(Palette p, String t, {String? extra, String? badge, Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Row(children: [
          Container(width: 3, height: 13, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: p.fg.withOpacity(.85))),
          if (extra != null) Text('  $extra', style: TextStyle(fontSize: 11, color: p.muted)),
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: p.accent.withOpacity(.16), borderRadius: BorderRadius.circular(99)),
              child: Text(badge, style: TextStyle(color: p.accent, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
      );

  // ---------------------------------------------------------------- step 0: category
  Future<void> _pickCat(J c) async {
    final s = StoreScope.read(context);
    final subs = s.categories.where((x) => x['parent'] == c['id']).toList();
    String? id = '${c['id']}';
    if (subs.isNotEmpty && search.text.trim().isEmpty) {
      id = await _subSheet(context, c);
    }
    if (id == null || !mounted) return;
    setState(() => catId = id);
    _go(1);
  }

  Widget _catTile(Palette p, J c, {bool small = false}) {
    final on = catId == c['id'];
    return _Pressable(
      onTap: () => _pickCat(c),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: small ? 48 : 56,
          height: small ? 48 : 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Color.alphaBlend(p.fg.withOpacity(.06), p.card),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? p.accent : p.line, width: on ? 1.6 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Text('${c['icon'] ?? '📦'}', style: TextStyle(fontSize: small ? 22 : 27)),
        ),
        const SizedBox(height: 6),
        Text('${c['name']}', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: small ? p.muted : null)),
      ]),
    );
  }

  Widget _catGrid(Palette p, List<J> list) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: .78,
        children: [
          for (var i = 0; i < list.length; i++) _Appear(index: i, child: _catTile(p, list[i])),
        ],
      );

  Widget _categoryStep(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final q = search.text.trim().toLowerCase();
    final all = s.categories.where((c) => c['kind'] == type && (q.isEmpty || '${c['name']}'.toLowerCase().contains(q))).toList();
    bool isMain(J c) => c['parent'] == null || '${c['parent']}'.isEmpty;
    final shown = q.isEmpty ? all.where(isMain).toList() : all;
    final freq = <String, int>{};
    final recent = s.txns.where((t) => t['catId'] != null && t['type'] == type).toList();
    for (final t in recent.skip(recent.length > 200 ? recent.length - 200 : 0)) {
      freq['${t['catId']}'] = (freq['${t['catId']}'] ?? 0) + 1;
    }
    final topIds = freq.keys.toList()..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    final top = <J>[];
    for (final id in topIds) {
      final c = s.cat(id);
      if (c != null && c['kind'] == type) top.add(c);
      if (top.length >= 8) break;
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select Category', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Choose a category for this transaction', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 18)),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create'),
          onPressed: () => showCategorySheet(context, kind: type),
        ),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search categories',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(search.clear)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: p.line)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
      if (top.isNotEmpty && q.isEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Icon(Icons.schedule_rounded, size: 14, color: p.muted),
          const SizedBox(width: 4),
          Text('Frequently Used', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) => _Pressable(
              onTap: () {
                setState(() => catId = '${top[i]['id']}');
                _go(1);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Text('${top[i]['icon'] ?? '📦'}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('${top[i]['name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
      ],
      _secLabel(p, 'All categories', badge: '${all.length}'),
      if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No categories match.', textAlign: TextAlign.center, style: TextStyle(color: p.muted))),
      _catGrid(p, shown),
    ]);
  }

  Future<String?> _subSheet(BuildContext context, J main) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) {
          final s = StoreScope.of(c);
          final p = Palette.of(c);
          final subs = s.categories.where((x) => x['parent'] == main['id']).toList();
          Widget tile(J x) => _Pressable(
                onTap: () => Navigator.pop(c, '${x['id']}'),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Color.alphaBlend(p.fg.withOpacity(.06), p.card), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
                    child: Text('${x['icon'] ?? '📦'}', style: const TextStyle(fontSize: 25)),
                  ),
                  const SizedBox(height: 6),
                  Text('${x['name']}', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              );
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
            child: SafeArea(
              top: false,
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
                Row(children: [
                  const Expanded(child: Text('Select a subcategory', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Subcategory'),
                    onPressed: () => showCategorySheet(c, kind: type, parent: '${main['id']}'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('Select a subcategory or choose the main category below.', style: TextStyle(color: p.muted, fontSize: 12)),
                _secLabel(p, 'General'),
                Align(alignment: Alignment.centerLeft, child: SizedBox(width: 80, child: tile(main))),
                Divider(color: p.line, height: 28),
                _secLabel(p, 'Subcategories'),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: .8,
                  children: [for (var i = 0; i < subs.length; i++) _Appear(index: i, child: tile(subs[i]))],
                ),
              ]),
            ),
          );
        },
      );

  // ---------------------------------------------------------------- step 1: account + calculator
  Widget _amountStep(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cur = s.accCur(accId);
    final hasOp = RegExp(r'[÷×\-+]').hasMatch(expr);
    final c = s.cat(catId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (c != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Text('${c['icon'] ?? ''}', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(child: Text('${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: (inc ? p.pos : p.neg).withOpacity(.14), borderRadius: BorderRadius.circular(99)),
                child: Text(inc ? 'Income' : 'Expense', style: TextStyle(color: inc ? p.pos : p.neg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(onPressed: () => _go(0), child: const Text('Change')),
            ]),
          ),
        _secLabel(
          p,
          'Select Account',
          trailing: TextButton.icon(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, backgroundColor: p.accent.withOpacity(.08), shape: const StadiumBorder()),
            onPressed: () => showWalletSheet(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add new account', style: TextStyle(fontSize: 12)),
          ),
        ),
        _AccRow(value: accId, onChanged: (v) => setState(() => accId = v)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: Color.alphaBlend(p.fg.withOpacity(.05), p.card), borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Enter Amount', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text(currencySymbol(cur), style: TextStyle(fontSize: 17, color: p.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text(expr.isEmpty ? '0' : expr, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: hasOp ? Text('= ${money(evalExpr(expr), cur)}', style: TextStyle(color: p.muted, fontSize: 12)) : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(child: _Keypad(onKey: _key)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () {
                  if (_checkAmount()) _save();
                },
                child: const Text('Quick Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: BorderSide(color: p.accent, width: 1.4)),
                onPressed: () {
                  if (_checkAmount()) _go(2);
                },
                child: const Text('Add More Details', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------- step 2: details
  Future<void> _pickReceipt() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final b = r?.files.single.bytes;
      if (b == null) return;
      final url = await _shrinkImage(b);
      if (mounted) setState(() => receipt = url);
    } catch (_) {
      if (mounted) toast(context, 'Couldn’t open that image');
    }
  }

  Widget _detailsStep(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cur = s.accCur(accId);
    final pl = planId == null ? null : s.splan(planId!);
    final td = today();
    String dayLabel(String d) => d == td ? 'Today' : weekday(d);
    final boxDeco = BoxDecoration(color: Color.alphaBlend(p.fg.withOpacity(.03), p.card), borderRadius: BorderRadius.circular(16), border: Border.all(color: p.accent.withOpacity(.28)));

    Widget half(IconData ic, String label, String small, String big, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(ic, size: 12, color: p.accent), const SizedBox(width: 4), Text(label, style: TextStyle(color: p.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8))]),
                    const SizedBox(height: 4),
                    Text(small, style: TextStyle(color: p.muted, fontSize: 10.5)),
                    Text(big, style: TextStyle(fontWeight: FontWeight.w800, fontSize: big.length > 10 ? 14 : 18)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
              ]),
            ),
          ),
        );

    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 2),
            child: Text('Add Note, Tags, Receipt, or Date', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          _secLabel(p, 'Date & Time'),
          Container(
            decoration: boxDeco,
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(children: [
                half(Icons.calendar_today_rounded, 'DATE', dayLabel(date) == 'Today' ? weekday(date) : dayLabel(date), fmtDate(date), () async {
                  final d = await showDatePicker(context: context, initialDate: parseDate(date), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => date = isoDate(d));
                }),
                VerticalDivider(width: 1, color: p.line),
                half(Icons.schedule_rounded, 'TIME', date == td ? 'Today' : weekday(date), fmtTime(time), () async {
                  final parts = time.split(':');
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0));
                  if (t != null) setState(() => time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00');
                }),
              ]),
            ),
          ),
          if (!inc) ...[
            _secLabel(p, 'Spending Plan', extra: '(Optional)'),
            Container(
              decoration: boxDeco,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  final x = await _pickPlanSheet(context, planId);
                  if (x != null) setState(() => planId = x.isEmpty ? null : x);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: p.accent.withOpacity(.14), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.calendar_month_rounded, size: 18, color: p.accent)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SPENDING PLAN', style: TextStyle(color: p.accent, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                        Text(pl == null ? 'Select a spending plan' : '${pl['name']}', style: TextStyle(color: pl == null ? p.muted : null, fontWeight: pl == null ? FontWeight.w400 : FontWeight.w700, fontSize: 13.5)),
                      ]),
                    ),
                    if (pl != null)
                      InkWell(
                        onTap: () => setState(() => planId = null),
                        child: Container(width: 28, height: 28, decoration: BoxDecoration(color: p.neg.withOpacity(.14), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close_rounded, size: 16, color: p.neg)),
                      )
                    else
                      Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
                  ]),
                ),
              ),
            ),
          ],
          _secLabel(p, 'Tags'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: boxDeco,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in s.tags)
                _TagPill(
                  label: '${t['name']}',
                  on: tags.contains('${t['name']}'),
                  onTap: () => setState(() {
                    final n = '${t['name']}';
                    if (tags.contains(n)) {
                      tags.remove(n);
                    } else {
                      tags.add(n);
                    }
                  }),
                ),
              _Pressable(
                onTap: () => showTagDialog(context, null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: p.accent)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 16, color: p.accent),
                    const SizedBox(width: 4),
                    Text('Add tag', style: TextStyle(color: p.accent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
          if (cur != s.base) ...[
            _secLabel(p, 'Conversion rate'),
            TextField(
              controller: rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                prefixText: '1 $cur = ',
                suffixText: s.base,
                suffixStyle: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
                hintText: 'Leave blank to use saved rate (${s.rates.rateOf(cur, s.base).toStringAsFixed(4)})',
                hintStyle: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ),
          ],
          _secLabel(p, 'Note'),
          TextField(controller: note, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: 'Add a note...')),
          _secLabel(p, 'Receipt'),
          if (receipt != null)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(base64Decode(receipt!.split(',').last), height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Center(child: Text('Receipt added')))),
              ),
              TextButton.icon(onPressed: () => setState(() => receipt = null), icon: Icon(Icons.delete_outline_rounded, color: p.neg), label: Text('Remove receipt', style: TextStyle(color: p.neg))),
            ])
          else
            _Pressable(
              onTap: _pickReceipt,
              child: Container(
                height: 110,
                decoration: boxDeco,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: p.accent.withOpacity(.14), shape: BoxShape.circle), child: Icon(Icons.cloud_upload_outlined, color: p.accent, size: 22)),
                  const SizedBox(height: 10),
                  Text('Click here to upload a receipt', style: TextStyle(color: p.muted, fontSize: 12)),
                ]),
              ),
            ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: _save, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700))),
          ),
        ),
      ),
    ]);
  }
}

/// Resizes a photo to max 1000 px and stores it as a JPEG data URL (same as the web app).
Future<String> _shrinkImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final fr = await codec.getNextFrame();
    final w0 = fr.image.width, h0 = fr.image.height;
    final sc = (1000 / (w0 > h0 ? w0 : h0)).clamp(0.0, 1.0).toDouble();
    final tw = (w0 * sc).round(), th = (h0 * sc).round();
    final codec2 = await ui.instantiateImageCodec(bytes, targetWidth: tw, targetHeight: th);
    final im = (await codec2.getNextFrame()).image;
    final raw = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) throw 'x';
    final rgba = raw.buffer.asUint8List();
    final jpg = await Isolate.run(() => img.encodeJpg(img.Image.fromBytes(width: tw, height: th, bytes: rgba.buffer, numChannels: 4), quality: 72));
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  } catch (_) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }
}

/// "Select Spending Plan" sheet: search, plan cards and a None button. Returns the id, '' for none, null when closed.
Future<String?> _pickPlanSheet(BuildContext context, String? current) {
  final s = StoreScope.read(context);
  final L = [...s.splans]..sort((a, b) {
      final x = (s.splanActive(b) ? 1 : 0) - (s.splanActive(a) ? 1 : 0);
      return x != 0 ? x : '${b['start']}'.compareTo('${a['start']}');
    });
  var q = '';
  String range(J pl) {
    final a = '${pl['start'] ?? ''}', b = '${pl['end'] ?? ''}';
    String f(String d) => d.length >= 10 ? fmtDate(d).replaceAll(RegExp(r', \d{4}$'), '') : d;
    return b.isEmpty ? f(a) : '${f(a)} - ${f(b)}';
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      final list = L.where((pl) => q.isEmpty || '${pl['name']} ${pl['desc'] ?? ''}'.toLowerCase().contains(q)).toList();
      return SizedBox(
        height: MediaQuery.of(c).size.height * .78,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(children: [
                const Expanded(child: Text('Select Spending Plan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(onChanged: (v) => set(() => q = v.trim().toLowerCase()), decoration: const InputDecoration(hintText: 'Search spending plans...', prefixIcon: Icon(Icons.search_rounded))),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text('No spending plans found', style: TextStyle(color: p.muted)))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), children: [
                      for (var i = 0; i < list.length; i++)
                        _Appear(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: current == list[i]['id'] ? p.accent.withOpacity(.12) : Color.alphaBlend(p.fg.withOpacity(.04), p.card),
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.pop(c, '${list[i]['id']}'),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(children: [
                                    Container(width: 40, height: 40, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle), child: Icon(Icons.calendar_month_rounded, color: p.accentInk, size: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${list[i]['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                        if ('${list[i]['desc'] ?? ''}'.isNotEmpty) Text('${list[i]['desc']}', style: TextStyle(color: p.muted, fontSize: 12)),
                                        Text(range(list[i]), style: TextStyle(color: p.muted, fontSize: 11)),
                                      ]),
                                    ),
                                    Icon(current == list[i]['id'] ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: current == list[i]['id'] ? p.accent : p.muted),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: SizedBox(height: 48, child: OutlinedButton(style: OutlinedButton.styleFrom(shape: const StadiumBorder()), onPressed: () => Navigator.pop(c, ''), child: const Text('None'))),
              ),
            ),
          ]),
        ),
      );
    }),
  );
}

/// Compact account chips (name + balance, ✓ on the selected one).
class _AccRow extends StatefulWidget {
  const _AccRow({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;
  @override
  State<_AccRow> createState() => _AccRowState();
}

class _AccRowState extends State<_AccRow> {
  final _sc = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sc.hasClients) return;
      final s = StoreScope.read(context);
      final i = s.accounts.indexWhere((a) => a['id'] == widget.value);
      if (i > 1) _sc.jumpTo(((i - 1) * 108.0).clamp(0, _sc.position.maxScrollExtent).toDouble());
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final list = s.accounts;
    if (list.isEmpty) return Text('Create an account first', style: TextStyle(color: p.muted));
    return SizedBox(
      height: 56,
      child: ListView.separated(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = list[i];
          final on = a['id'] == widget.value;
          final b = s.accBal(a);
          return _Pressable(
            onTap: () => widget.onChanged('${a['id']}'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minWidth: 92),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: on ? p.accent.withOpacity(.12) : Color.alphaBlend(p.fg.withOpacity(.05), p.card),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? p.accent : p.line, width: on ? 1.6 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${a['name']}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: on ? p.accent : null)),
                  if (on) ...[const SizedBox(width: 4), Icon(Icons.check_circle_rounded, size: 13, color: p.accent)],
                ]),
                const SizedBox(height: 2),
                Text(money(b, '${a['currency']}'), style: TextStyle(color: p.muted, fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Calculator keypad: 7 8 9 ÷ / 4 5 6 × / 1 2 3 − / C 0 ⌫ + / . =
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final ValueChanged<String> onKey;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final digitBg = Color.alphaBlend(p.fg.withOpacity(.07), p.card);
    final opBg = Color.alphaBlend(p.accent.withOpacity(.13), p.card);
    final cBg = Color.alphaBlend(p.neg.withOpacity(.14), p.card);
    Widget key(String k, {int flex = 1}) {
      final isOp = '÷×-+'.contains(k) || k == '⌫';
      final bg = k == '=' ? p.accent : k == 'C' ? cBg : isOp ? opBg : digitBg;
      final fg = k == '=' ? p.accentInk : k == 'C' ? p.neg : isOp ? p.accent : p.fg;
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _Pressable(
            scale: .92,
            onTap: () => onKey(k),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: (k == '=' ? p.accent : Colors.black).withOpacity(k == '=' ? .35 : .16), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: k == '⌫' ? Icon(Icons.backspace_outlined, color: fg, size: 22) : Text(k == '-' ? '−' : k, style: TextStyle(color: fg, fontSize: 22, fontWeight: isOp || k == '=' ? FontWeight.w700 : FontWeight.w600)),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> c) => Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: c));
    return Column(children: [
      row([key('7'), key('8'), key('9'), key('÷')]),
      row([key('4'), key('5'), key('6'), key('×')]),
      row([key('1'), key('2'), key('3'), key('-')]),
      row([key('C'), key('0'), key('⌫'), key('+')]),
      row([key('.'), key('=', flex: 3)]),
    ]);
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? p.accent.withOpacity(.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? p.accent : p.line, width: on ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: on ? Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_circle_rounded, size: 16, color: p.accent)) : const SizedBox.shrink(),
          ),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? p.fg : p.fg.withOpacity(.85))),
        ]),
      ),
    );
  }
}

/// Shrinks a little while pressed (tactile feel).
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap, this.scale = .95});
  final Widget child;
  final VoidCallback onTap;
  final double scale;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(scale: down ? widget.scale : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut, child: widget.child),
      );
}

/// Fades and lifts children in, one after another.
class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + (index.clamp(0, 12) * 30)),
        curve: Curves.easeOutCubic,
        builder: (_, t, ch) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: ch)),
        child: child,
      );
}
