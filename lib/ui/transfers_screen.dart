import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/ops.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'widgets.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final list = s.transfers;
    return Scaffold(
      appBar: AppBar(title: const Text('Account Transfers')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: p.accent,
        foregroundColor: p.accentInk,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(pageRoute(const TransferEditScreen())),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        if (list.isEmpty) const EmptyNote('No transfers yet. Tap + to move money between accounts.', icon: Icons.swap_horiz_rounded),
        for (final t in list) ...[
          _TransferCard(out: t),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.out});
  final J out;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final inn = s.transferIn(out);
    final g = '${out['group']}';
    final fc = s.accCur(out['accId']);
    final tc = inn == null ? fc : s.accCur(inn['accId']);
    final fx = s.transferFx(g);
    final fee = s.transferFee(g);
    final rate = toD(out['fxRate']);
    final dir = '${out['fxDir'] ?? 'fwd'}';
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(15), border: Border.all(color: p.line)),
            child: Icon(Icons.swap_horiz_rounded, color: p.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'From ', style: TextStyle(color: p.muted)),
                TextSpan(text: s.accName(out['accId']), style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
              Icon(Icons.arrow_downward_rounded, size: 16, color: p.muted),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'To ', style: TextStyle(color: p.muted)),
                TextSpan(text: s.accName(out['peer']), style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
            ]),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.of(context).push(pageRoute(TransferEditScreen(out: out)));
              } else {
                final ok = await confirmDialog(context, 'Delete transfer?', 'Both sides of the transfer, any fee and any exchange gain/loss will be removed.');
                if (ok) {
                  s.deleteTransfer(g);
                  if (context.mounted) toast(context, 'Transfer deleted');
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit transfer'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: p.neg), title: Text('Delete transfer', style: TextStyle(color: p.neg)), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ]),
        Divider(height: 24, color: p.line),
        Row(children: [
          Expanded(
            child: Text(
              inn != null && tc != fc ? '${money(toD(out['amount']), fc)} → ${money(toD(inn['amount']) + fx, tc)}' : money(toD(out['amount']), fc),
              style: TextStyle(color: p.pos, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          Text(fmtDate('${out['date']}'), style: TextStyle(color: p.muted, fontSize: 13)),
        ]),
        if (rate > 0 && inn != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(TextSpan(style: TextStyle(color: p.muted, fontSize: 12.5), children: [
              TextSpan(text: 'My rate ${dir == 'rev' ? '1 $tc = ${(1 / rate).toStringAsFixed(4)} $fc' : '1 $fc = ${rate.toStringAsFixed(4)} $tc'}'),
              if (fx != 0) TextSpan(text: ' · Exchange ${fx > 0 ? 'gain' : 'loss'} ${money(fx.abs(), tc)}', style: TextStyle(color: fx > 0 ? p.pos : p.neg)),
            ])),
          ),
        if (fee > 0) Text('Fee ${money(fee, fc)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
        if ('${out['note'] ?? ''}'.isNotEmpty) Text('≡ ${out['note']}', style: TextStyle(color: p.muted, fontSize: 13)),
      ]),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'Delete'}) async {
  final p = Palette.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: Text(ok, style: TextStyle(color: p.neg))),
      ],
    ),
  );
  return r == true;
}

/// New or edit transfer, with the optional own exchange rate (gain / loss) like the web app.
class TransferEditScreen extends StatefulWidget {
  const TransferEditScreen({super.key, this.out, this.presetFrom, this.presetTo});
  final J? out;
  final String? presetFrom, presetTo;
  @override
  State<TransferEditScreen> createState() => _TransferEditScreenState();
}

class _TransferEditScreenState extends State<TransferEditScreen> {
  String? from, to;
  final amt = TextEditingController();
  final fee = TextEditingController();
  final note = TextEditingController();
  final rateCtl = TextEditingController();
  final recvCtl = TextEditingController();
  String date = today();
  String? dir; // fwd = "1 FROM = x TO", rev = "1 TO = x FROM"
  String? editGroup, editTime;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final o = widget.out;
    if (o != null) {
      final inn = s.transferIn(o);
      final g = '${o['group']}';
      editGroup = g;
      editTime = o['time']?.toString();
      from = '${o['accId']}';
      to = '${o['peer']}';
      amt.text = _num(toD(o['amount']));
      final f = s.transferFee(g);
      fee.text = f > 0 ? _num(f) : '';
      date = '${o['date']}';
      note.text = '${o['note'] ?? ''}';
      final r = toD(o['fxRate']);
      if (r > 0 && inn != null) {
        dir = '${o['fxDir'] ?? 'fwd'}';
        rateCtl.text = _num6(dir == 'rev' ? 1 / r : r);
        recvCtl.text = _num(round2(toD(inn['amount']) + s.transferFx(g)));
      }
    } else {
      from = widget.presetFrom ?? s.defaultAccId;
      to = widget.presetTo;
    }
  }

  String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  String _num6(double v) => double.parse(v.toStringAsFixed(6)).toString();
  double _p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  String _dir(String fc, String tc) => dir ?? (StoreScope.read(context).fxStrong(fc, tc) ? 'fwd' : 'rev');

  /// to-currency per 1 from-currency (0 when not typed)
  double _rate(String fc, String tc) {
    final v = _p(rateCtl);
    if (v <= 0) return 0;
    return _dir(fc, tc) == 'rev' ? 1 / v : v;
  }

  void _syncFromRate(String fc, String tc) {
    final r = _rate(fc, tc), v = _p(amt);
    recvCtl.text = r > 0 && v > 0 ? _num(round2(v * r)) : '';
  }

  void _syncFromRecv(String fc, String tc) {
    final rv = _p(recvCtl), v = _p(amt);
    if (rv > 0 && v > 0) {
      final r = rv / v;
      rateCtl.text = _num6(_dir(fc, tc) == 'rev' ? 1 / r : r);
    } else {
      rateCtl.text = '';
    }
  }

  Future<void> _pick(bool isFrom) async {
    final s = StoreScope.read(context);
    final other = isFrom ? to : from;
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(isFrom ? 'From Account' : 'To Account', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final a in s.accounts.where((a) => a['id'] != other))
            ListTile(
              leading: Icon(s.isCard(a) ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined),
              title: Text('${a['name']}'),
              subtitle: Text(money(s.accBal(a), '${a['currency']}')),
              trailing: (isFrom ? from : to) == a['id'] ? Icon(Icons.check_rounded, color: Palette.of(c).accent) : null,
              onTap: () => Navigator.pop(c, '${a['id']}'),
            ),
        ]),
      ),
    );
    if (id == null) return;
    setState(() {
      if ((isFrom ? from : to) != id) {
        rateCtl.clear();
        recvCtl.clear();
        dir = null;
      }
      if (isFrom) {
        from = id;
      } else {
        to = id;
      }
    });
  }

  void _save() {
    final s = StoreScope.read(context);
    final v = _p(amt);
    if (from == null || to == null) return toast(context, 'Choose both accounts');
    if (from == to) return toast(context, 'Choose two different accounts');
    if (v <= 0) return toast(context, 'Enter an amount above zero');
    final fc = s.accCur(from), tc = s.accCur(to);
    final cx = fc != tc;
    HapticFeedback.lightImpact();
    s.saveTransfer(
      editGroup: editGroup,
      editTime: editTime,
      from: from!,
      to: to!,
      amount: v,
      fee: _p(fee),
      date: date,
      note: note.text.trim(),
      rate: cx ? _rate(fc, tc) : 0,
      dir: cx ? _dir(fc, tc) : 'fwd',
    );
    Navigator.pop(context);
    toast(context, editGroup != null ? 'Transfer updated' : 'Transfer completed successfully');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final fa = s.acc(from), ta = s.acc(to);
    final fc = fa == null ? s.base : '${fa['currency']}';
    final tc = ta == null ? s.base : '${ta['currency']}';
    final cx = fa != null && ta != null && fc != tc;
    final v = _p(amt);
    final r = cx ? _rate(fc, tc) : 0.0;
    final d = cx ? _dir(fc, tc) : 'fwd';
    final qa = d == 'rev' ? tc : fc, qb = d == 'rev' ? fc : tc;
    final appQ = s.rates.rateOf(qa, qb);
    final appAmt = cx ? round2(s.conv(v, fc, tc)) : 0.0;
    final real = r > 0 ? round2(v * r) : 0.0;
    final diff = round2(real - appAmt);

    Widget accBox(String label, J? a, bool isFrom) => GlassCard(
          onTap: () => _pick(isFrom),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.accent.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(a != null && s.isCard(a) ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: p.muted, fontSize: 12.5)),
                Text(a == null ? 'Choose account' : '${a['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                if (a != null) Text('${a['currency']} · ${money(s.accBal(a), '${a['currency']}')}', style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(editGroup != null ? 'Edit Transfer' : 'Transfer Between Accounts')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        accBox('From account', fa, true),
        Center(
          child: IconButton(
            tooltip: 'Swap accounts',
            icon: const Icon(Icons.swap_vert_rounded),
            onPressed: () => setState(() {
              final x = from;
              from = to;
              to = x;
              rateCtl.clear();
              recvCtl.clear();
              dir = null;
            }),
          ),
        ),
        accBox('To account', ta, false),
        const SizedBox(height: 14),
        TextField(
          controller: amt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(labelText: 'Amount', prefixText: '${currencySymbol(fc)} '),
          onChanged: (_) => setState(() {
            if (cx) _syncFromRate(fc, tc);
          }),
        ),
        if (cx && r <= 0 && v > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('≈ ${money(appAmt, tc)} at ${s.rates.rateOf(fc, tc).toStringAsFixed(4)}', style: TextStyle(color: p.pos, fontSize: 13)),
          ),
        if (cx) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Exchange rate (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Use the rate from your bank statement. It applies to this transfer only.', style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 12),
              Row(children: [
                const Text('1 '),
                ActionChip(
                  label: Text('$qa  ⇄', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
                  onPressed: () => setState(() {
                    final cur = _p(rateCtl);
                    dir = d == 'rev' ? 'fwd' : 'rev';
                    if (cur > 0) rateCtl.text = _num6(1 / cur);
                  }),
                ),
                const Text('  =  '),
                Expanded(
                  child: TextField(
                    controller: rateCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(hintText: appQ.toStringAsFixed(4), isDense: true),
                    onChanged: (_) => setState(() => _syncFromRate(fc, tc)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(qb, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: recvCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount received in ${ta?['name'] ?? ''} ($tc)', hintText: v > 0 ? appAmt.toStringAsFixed(2) : '0.00'),
                onChanged: (_) => setState(() => _syncFromRecv(fc, tc)),
              ),
              if (r > 0 && v > 0) ...[
                const SizedBox(height: 12),
                _line(p, 'At app rate (1 $qa = ${appQ.toStringAsFixed(4)} $qb)', money(appAmt, tc)),
                _line(p, 'At your rate', money(real, tc)),
                if (diff.abs() >= 0.01) ...[
                  Divider(color: p.line),
                  _line(p, 'Exchange ${diff > 0 ? 'gain' : 'loss'}', '${diff > 0 ? '+' : '−'}${money(diff.abs(), tc)}', color: diff > 0 ? p.pos : p.neg, bold: true),
                  Text('Recorded as ${diff > 0 ? 'income' : 'an expense'} ("Exchange ${diff > 0 ? 'Gain' : 'Loss'}") in ${ta?['name'] ?? ''}.', style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ],
            ]),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: fee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Transfer fee (optional)', prefixText: '${currencySymbol(fc)} '),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_rounded, size: 18),
          label: Text(fmtDate(date)),
          onPressed: () async {
            final x = await showDatePicker(context: context, initialDate: parseDate(date), firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (x != null) setState(() => date = isoDate(x));
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        const SizedBox(height: 22),
        FilledButton(onPressed: _save, child: Text(editGroup != null ? 'Save Changes' : 'Transfer')),
      ]),
    );
  }

  Widget _line(Palette p, String k, String v, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: color ?? p.muted, fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(v, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}
