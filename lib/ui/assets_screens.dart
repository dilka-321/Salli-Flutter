import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/loans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

/// My Assets: property, vehicles, gold, investments and fixed deposits (FD interest posts automatically).
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = StoreScope.read(context).runFDInterest();
      if (n > 0) toast(context, '$n FD interest payment${n > 1 ? 's' : ''} added');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final tot = s.assets.fold(0.0, (a, x) => a + s.assetBase(x));
    final g = <String, List<J>>{};
    for (final a in s.assets) {
      g.putIfAbsent('${a['typeId']}', () => []).add(a);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Assets')),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(pageRoute(const AssetFormScreen())), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.16), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total asset value', style: TextStyle(color: p.muted)),
            Text(moneyB(s, tot), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.pos)),
            Text('Plus ${moneyB(s, s.totalBalance)} in your accounts', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
        if (s.assets.isEmpty) const EmptyNote('No assets yet\nAdd property, vehicles, gold, fixed deposits and investments', icon: Icons.work_outline_rounded),
        for (final e in g.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Row(children: [
              Expanded(child: Text('${s.atype(e.key)?['icon'] ?? ''} ${s.atype(e.key)?['name'] ?? 'Other'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(moneyB(s, e.value.fold(0.0, (a, x) => a + s.assetBase(x))), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
          for (final a in e.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(builder: (_) {
                final fd = s.isFD(a) ? s.fdOf(a) : null;
                final next = fd != null ? s.fdNext(a) : null;
                return GlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(children: [
                    EmojiTile('${s.atype(a['typeId']?.toString())?['icon'] ?? '💼'}', tint: p.pos),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${a['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (fd != null) ...[
                          Text('${toD(fd['rate']).toStringAsFixed(2)}% ${fd['basis'] == 'monthly' ? 'monthly' : 'yearly'} · matures ${fmtDate(s.fdMaturity(a))}', style: TextStyle(color: p.muted, fontSize: 12)),
                          Text('Interest ${fd['payout'] == 'maturity' ? 'at maturity' : 'monthly'} → ${s.accName(fd['accId'])}${next != null ? ' · next ${fmtDate(next)}' : ''}', style: TextStyle(color: p.pos, fontSize: 12)),
                        ],
                        if ('${a['note'] ?? ''}'.isNotEmpty) Text('${a['note']}', style: TextStyle(color: p.muted, fontSize: 12)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fd != null ? money(toD(a['value']), '${fd['currency'] ?? s.base}') : moneyB(s, toD(a['value'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (fd != null && fd['currency'] != s.base) Text('≈ ${moneyB(s, s.assetBase(a))}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                    ]),
                    moreMenu([
                      ('Edit', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(AssetFormScreen(existing: a))), false),
                      (
                        'Delete',
                        Icons.delete_outline,
                        () async {
                          if (await confirmDialog(context, 'Delete asset?', 'Interest already paid into your account stays.')) {
                            s.deleteAsset('${a['id']}');
                            if (context.mounted) toast(context, 'Asset deleted');
                          }
                        },
                        true
                      ),
                    ]),
                  ]),
                );
              }),
            ),
        ],
      ]),
    );
  }
}

class AssetFormScreen extends StatefulWidget {
  const AssetFormScreen({super.key, this.existing});
  final J? existing;
  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final name = TextEditingController();
  final value = TextEditingController();
  final note = TextEditingController();
  final rate = TextEditingController();
  final months = TextEditingController(text: '12');
  String? typeId, accId;
  late String currency;
  String basis = 'yearly', payout = 'monthly', start = today();
  String? err;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = StoreScope.read(context);
    final a = widget.existing;
    final types = s.assetTypes.where((t) => t['kind'] == 'asset').toList();
    typeId = types.isEmpty ? null : '${types.first['id']}';
    currency = s.base;
    accId = s.defaultAccId;
    if (a != null) {
      name.text = '${a['name'] ?? ''}';
      typeId = '${a['typeId']}';
      value.text = plainNum(toD(a['value']));
      note.text = '${a['note'] ?? ''}';
      if (s.isFD(a)) {
        final f = s.fdOf(a);
        currency = '${f['currency'] ?? s.base}';
        rate.text = plainNum(toD(f['rate']));
        basis = '${f['basis'] ?? 'yearly'}';
        start = '${f['start'] ?? today()}';
        months.text = plainNum(toD(f['months']));
        payout = '${f['payout'] ?? 'monthly'}';
        accId = f['accId']?.toString();
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, value, note, rate, months]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = StoreScope.read(context);
    final v = parseAmount(value.text);
    final fd = s.atype(typeId)?['fd'] == true;
    String? e;
    if (name.text.trim().isEmpty) {
      e = 'Enter a name.';
    } else if (v == null || v < 0 || (fd && v <= 0)) {
      e = fd ? 'Enter the deposit amount.' : 'Enter the value.';
    }
    J? f;
    if (e == null && fd) {
      final r = parseAmount(rate.text) ?? 0, m = int.tryParse(months.text.trim()) ?? 0;
      if (r <= 0) {
        e = 'Enter the interest rate.';
      } else if (m <= 0) {
        e = 'Enter the term in months.';
      } else if (accId == null) {
        e = 'Choose the account for interest.';
      } else {
        f = <String, dynamic>{'currency': currency, 'rate': r, 'basis': basis, 'start': start, 'months': m, 'payout': payout, 'accId': accId};
      }
    }
    if (e != null) return setState(() => err = e);
    final n = s.saveAsset(id: widget.existing?['id']?.toString(), name: name.text.trim(), typeId: typeId ?? '', value: v!, note: note.text, fd: f);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    toast(context, n > 0 ? 'Asset saved · $n interest payment${n > 1 ? 's' : ''} added' : 'Asset saved');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final types = s.assetTypes.where((t) => t['kind'] == 'asset').toList();
    final fd = s.atype(typeId)?['fd'] == true;
    final v = parseAmount(value.text) ?? 0, r = parseAmount(rate.text) ?? 0, m = int.tryParse(months.text.trim()) ?? 12;
    final mi = fd ? v * r / 100 / (basis == 'monthly' ? 1 : 12) : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Asset' : 'Add Asset')),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 10), child: FilledButton(onPressed: _save, child: const Text('Save')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        TextField(controller: name, decoration: InputDecoration(labelText: 'Name', hintText: fd ? 'e.g. BOC 12-month FD' : 'e.g. Toyota Aqua')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: types.any((t) => t['id'] == typeId) ? typeId : null,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final t in types) DropdownMenuItem(value: '${t['id']}', child: Text('${t['icon']} ${t['name']}'))],
          onChanged: (x) => setState(() => typeId = x),
        ),
        const SizedBox(height: 12),
        if (fd) ...[
          FieldRow(
            icon: Icons.currency_exchange_rounded,
            label: 'FD currency',
            value: '$currency — ${kCurrencyMap[currency]?.name ?? ''}',
            onTap: () async {
              final c = await pickCurrency(context, currency);
              if (c != null) setState(() => currency = c);
            },
          ),
          AmountBox(controller: value, currency: currency, label: 'Deposit amount ($currency)', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Interest rate (%)'))),
            const SizedBox(width: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'yearly', label: Text('Yearly')), ButtonSegment(value: 'monthly', label: Text('Monthly'))],
              selected: {basis},
              onSelectionChanged: (x) => setState(() => basis = x.first),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DateButton(value: start, label: 'Start', onChanged: (x) => setState(() => start = x))),
            const SizedBox(width: 10),
            SizedBox(width: 120, child: TextField(controller: months, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Term (months)'))),
          ]),
          const SizedBox(height: 12),
          Text('Pay interest', style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'monthly', label: Text('Monthly')), ButtonSegment(value: 'maturity', label: Text('At maturity'))],
            selected: {payout},
            onSelectionChanged: (x) => setState(() => payout = x.first),
          ),
          const SectionTitle('Deposit interest into'),
          AccountChips(value: accId, onChanged: (x) => setState(() => accId = x)),
          if (mi > 0) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                kvRow(p, 'Interest per month', money(mi, currency), color: p.pos),
                kvRow(p, 'Total interest ($m months)', money(mi * m, currency), color: p.pos),
                if (currency != s.base) kvRow(p, 'Deposit in ${s.base}', moneyB(s, s.conv(v, currency, s.base))),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          Text('Interest is added to the selected account automatically on each payment date.', style: TextStyle(color: p.muted, fontSize: 12.5)),
        ] else
          TextField(controller: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Current value (${s.base})')),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: TextStyle(color: p.neg, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
