import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/currency_table.dart';
import '../core/ops.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'card_screen.dart';
import 'transactions_screen.dart';
import 'quick_tx.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My Accounts'), actions: [
        IconButton(tooltip: 'Transfers', icon: const Icon(Icons.swap_horiz_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const TransfersScreen()))),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: p.accent,
        foregroundColor: p.accentInk,
        shape: const CircleBorder(),
        onPressed: () => _addChooser(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(children: [
            GlassCard(
              gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withOpacity(.18), p.card), p.card]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('All Accounts Balance', style: TextStyle(color: p.muted)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(money(s.totalBalance, s.base), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
                Text('${s.wallets.length} accounts · main currency ${s.base}', style: TextStyle(color: p.muted, fontSize: 13)),
                Text('Long press a card to set as default · drag ☰ to reorder', style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ),
            const SectionTitle('Wallets & bank accounts'),
            if (s.wallets.isEmpty) const EmptyNote('No accounts yet. Tap + to add one.'),
          ]),
        ),
        // wallets: drag the ☰ handle to change their order (used everywhere accounts are listed)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: s.wallets.length,
            proxyDecorator: (child, i, a) => AnimatedBuilder(
              animation: a,
              builder: (_, ch) => Transform.scale(scale: 1 + .03 * Curves.easeOut.transform(a.value), child: Material(type: MaterialType.transparency, child: ch)),
              child: child,
            ),
            onReorder: (from, to) {
              final w = [...s.wallets];
              if (to > from) to -= 1;
              w.insert(to, w.removeAt(from));
              final others = s.accounts.where((a) => s.isCard(a)).toList();
              final list = s.data['accounts'] as List;
              list
                ..clear()
                ..addAll(w)
                ..addAll(others);
              s.commit();
            },
            itemBuilder: (_, i) {
              final a = s.wallets[i];
              return Padding(key: ValueKey('acc_${a['id']}'), padding: const EdgeInsets.only(bottom: 10), child: _AccCard(a: a, index: i));
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList.list(children: [
            SectionTitle('Credit cards', action: 'Add card', onAction: () => showCardSheet(context)),
            if (s.cards.isEmpty) const EmptyNote('No credit cards added.', icon: Icons.credit_card_off_outlined),
            for (final a in s.cards) ...[
              _AccCard(a: a),
              const SizedBox(height: 10),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _AccCard extends StatelessWidget {
  const _AccCard({required this.a, this.index});
  final J a;

  /// position in the reorderable wallet list (null for credit cards)
  final int? index;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cur = '${a['currency']}';
    final bal = s.accBal(a);
    final card = s.isCard(a);
    final limit = toD(a['limit']);
    final body = GlassCard(
      onTap: () => card ? Navigator.of(context).push(pageRoute(CardScreen(id: '${a['id']}'))) : _accountActions(context, a),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.accent.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(card ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded, color: p.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(children: [
                Text('$cur · ${currencyName(cur)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                if (a['isDefault'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: p.warn.withOpacity(.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('Default', style: TextStyle(color: p.warn, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ]),
          ),
          if (index != null)
            ReorderableDragStartListener(
              index: index!,
              child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.drag_handle_rounded, color: p.muted)),
            )
          else
            Icon(Icons.chevron_right_rounded, color: p.muted),
        ]),
        const SizedBox(height: 12),
        Text(card ? 'Available' : 'Balance', style: TextStyle(color: p.muted, fontSize: 12.5)),
        Text(money(bal, cur), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: bal < 0 ? p.neg : p.pos)),
        if (cur != s.base) Text('≈ ${money(s.accBalBase(a), s.base)}', style: TextStyle(color: p.muted, fontSize: 12.5)),
        if (card && limit > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: (1 - bal / limit).clamp(0.0, 1.0).toDouble(), minHeight: 6, backgroundColor: p.line, color: p.accent),
          ),
          const SizedBox(height: 4),
          Text('Used ${money(limit - bal, cur)} of ${money(limit, cur)}', style: TextStyle(color: p.muted, fontSize: 12)),
        ],
        if (a['include'] == false) Text('Not included in total balance', style: TextStyle(color: p.muted, fontSize: 12)),
        if (!card) ...[
          const SizedBox(height: 10),
          Row(children: [
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _correctBalanceSheet(context, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.tune_rounded, size: 15, color: p.muted),
                    const SizedBox(width: 6),
                    Text('Balance Re-correction', style: TextStyle(color: p.fg.withOpacity(.85), fontSize: 12)),
                  ]),
                ),
              ),
            ),
            const Spacer(),
            Text('Include', style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(width: 4),
            Switch(
              value: a['include'] != false,
              onChanged: (v) {
                a['include'] = v;
                s.commit();
                toast(context, v ? '${a['name']} is included in the total balance' : '${a['name']} is not included in the total balance');
              },
            ),
          ]),
        ],
      ]),
    );
    if (card) return body;
    // long press → set as default wallet
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        for (final w in s.wallets) {
          w['isDefault'] = w['id'] == a['id'];
        }
        s.commit();
        toast(context, '${a['name']} is now your default wallet');
      },
      child: body,
    );
  }
}

void _accountActions(BuildContext context, J a) {
  final s = StoreScope.read(context);
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.receipt_long_rounded),
          title: const Text('Transactions in this account'),
          onTap: () {
            Navigator.pop(c);
            Navigator.of(context).push(pageRoute(_AccountTxns(accId: '${a['id']}')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz_rounded),
          title: const Text('Transfer from this account'),
          onTap: () {
            Navigator.pop(c);
            Navigator.of(context).push(pageRoute(TransferEditScreen(presetFrom: '${a['id']}')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit account'),
          subtitle: const Text('Name, currency and balance'),
          onTap: () {
            Navigator.pop(c);
            showWalletSheet(context, existing: a);
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: Palette.of(c).neg),
          title: Text('Delete account', style: TextStyle(color: Palette.of(c).neg)),
          onTap: () async {
            Navigator.pop(c);
            final n = s.txCount('${a['id']}');
            final ok = await confirmDialog(context, 'Delete account?', n > 0 ? 'This also deletes its $n transaction${n > 1 ? 's' : ''}. This can’t be undone.' : 'This can’t be undone.');
            if (ok) {
              s.deleteAccount('${a['id']}');
              if (context.mounted) toast(context, 'Wallet deleted successfully');
            }
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// One account's page: green header with balance and the month's In / Out, month chips, day groups and a + button.
class _AccountTxns extends StatefulWidget {
  const _AccountTxns({required this.accId});
  final String accId;
  @override
  State<_AccountTxns> createState() => _AccountTxnsState();
}

class _AccountTxnsState extends State<_AccountTxns> {
  String month = ym(today());

  static const _mn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _chip(String k) => "${_mn[int.parse(k.substring(5, 7)) - 1]} '${k.substring(2, 4)}";

  Future<void> _menu(BuildContext context, int v, J a) async {
    final s = StoreScope.read(context);
    final id = widget.accId;
    switch (v) {
      case 0:
        _editAccountSheet(context, a);
      case 1:
        showWalletSheet(context);
      case 2:
        _correctBalanceSheet(context, a);
      case 3:
        for (final w in s.wallets) {
          w['isDefault'] = w['id'] == id;
        }
        s.commit();
        toast(context, '${a['name']} is now your default wallet');
      case 4:
        final n = s.txCount(id);
        final ok = await confirmDialog(context, 'Delete account?', n > 0 ? 'This also deletes its $n transaction${n > 1 ? 's' : ''}. This can’t be undone.' : 'This can’t be undone.');
        if (ok) {
          s.deleteAccount(id);
          if (context.mounted) {
            Navigator.pop(context);
            toast(context, 'Wallet deleted successfully');
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final a = s.acc(widget.accId);
    if (a == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('This account was deleted.'));
    final cur = '${a['currency']}';
    final all = s.txns.where((t) => t['accId'] == widget.accId).toList();
    // months: this month back to the oldest transaction (at least 12 months)
    final now = ym(today());
    var oldest = addMonthsYm(now, -11);
    for (final t in all) {
      final k = ym('${t['date']}');
      if (k.length == 7 && k.compareTo(oldest) < 0) oldest = k;
    }
    final months = <String>[];
    for (var k = now; k.compareTo(oldest) >= 0 && months.length < 240; k = addMonthsYm(k, -1)) {
      months.add(k);
    }
    if (!months.contains(month)) months.add(month);
    final list = all.where((t) => ym('${t['date']}') == month).toList()
      ..sort((x, y) => ('${y['date']}${y['time'] ?? ''}').compareTo('${x['date']}${x['time'] ?? ''}'));
    final inn = list.where((t) => t['type'] == 'income').fold(0.0, (v, t) => v + toD(t['amount']));
    final out = list.where((t) => t['type'] != 'income').fold(0.0, (v, t) => v + toD(t['amount']));
    final groups = <String, List<J>>{};
    for (final t in list) {
      groups.putIfAbsent('${t['date']}', () => []).add(t);
    }
    final bal = s.accBal(a);
    final top = MediaQuery.of(context).padding.top;
    const white = Colors.white;

    Widget pill(IconData ic, String label, double v) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Colors.black.withOpacity(.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: white.withOpacity(.22))),
            child: Row(children: [
              Icon(ic, size: 16, color: white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: TextStyle(color: white.withOpacity(.75), fontSize: 10)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money(v, cur), style: const TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 13))),
                ]),
              ),
            ]),
          ),
        );

    final header = Container(
      padding: EdgeInsets.fromLTRB(6, top + 4, 6, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(p.accent, white, .08)!, Color.lerp(p.accent, Colors.black, .45)!]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_rounded, color: white), onPressed: () => Navigator.maybePop(context)),
          const Spacer(),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded, color: white),
            onSelected: (v) => _menu(context, v, a),
            itemBuilder: (c) {
              final cp = Palette.of(c);
              PopupMenuItem<int> it(int v, IconData ic, String t, {Color? col}) => PopupMenuItem<int>(
                    value: v,
                    child: Row(children: [Icon(ic, size: 20, color: col), const SizedBox(width: 12), Text(t, style: TextStyle(color: col))]),
                  );
              return [
                it(0, Icons.edit_rounded, 'Edit Account'),
                it(1, Icons.add_circle_outline_rounded, 'Create Account'),
                const PopupMenuDivider(),
                it(2, Icons.tune_rounded, 'Correct Balance'),
                it(3, Icons.star_border_rounded, 'Set as Default Wallet'),
                const PopupMenuDivider(),
                it(4, Icons.delete_rounded, 'Delete Account', col: cp.neg),
              ];
            },
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['name']}', style: TextStyle(color: white.withOpacity(.92), fontSize: 15, fontWeight: FontWeight.w600)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money(bal, cur), style: const TextStyle(color: white, fontSize: 30, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today_rounded, size: 11, color: white.withOpacity(.75)),
              const SizedBox(width: 5),
              Text(fmtMonth(month), style: TextStyle(color: white.withOpacity(.75), fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            Row(children: [pill(Icons.south_west_rounded, 'In', inn), const SizedBox(width: 10), pill(Icons.north_east_rounded, 'Out', out)]),
          ]),
        ),
      ]),
    );

    final body = <Widget>[
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Expanded(child: Text('Recent Transactions', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
        Container(
          constraints: const BoxConstraints(minWidth: 22),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.fg.withOpacity(.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line)),
          child: Text('${list.length}', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: months.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = months[i];
            final on = k == month;
            return Material(
              color: on ? p.accent : Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: on ? p.accent : p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => month = k),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text(_chip(k), style: TextStyle(color: on ? p.accentInk : p.muted, fontSize: 12.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500))),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Text('Showing ${fmtMonth(month)} transactions', style: TextStyle(color: p.muted, fontSize: 11.5)),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: p.accent.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.receipt_long_rounded, color: p.accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('No transactions for this period', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
    ];
    groups.forEach((d, arr) {
      final gi = arr.where((t) => t['type'] == 'income').fold(0.0, (v, t) => v + toD(t['amount']));
      final go = arr.where((t) => t['type'] != 'income').fold(0.0, (v, t) => v + toD(t['amount']));
      body.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
            child: Text('${parseDate(d).day}', style: TextStyle(color: p.accentInk, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: p.accent.withOpacity(.16), borderRadius: BorderRadius.circular(6)),
            child: Text(weekday(d), style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (gi > 0) ...[Icon(Icons.south_west_rounded, size: 13, color: p.pos), const SizedBox(width: 3), Text(money(gi, cur), style: TextStyle(color: p.pos, fontSize: 12, fontWeight: FontWeight.w700))],
          if (gi > 0 && go > 0) const SizedBox(width: 10),
          if (go > 0) ...[Icon(Icons.north_east_rounded, size: 13, color: p.neg), const SizedBox(width: 3), Text(money(go, cur), style: TextStyle(color: p.neg, fontSize: 12, fontWeight: FontWeight.w700))],
        ]),
      ));
      for (final t in arr) {
        final inc = t['type'] == 'income';
        final col = inc ? p.pos : p.neg;
        body.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            onTap: () => showTxDetail(context, t),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: col.withOpacity(.14), shape: BoxShape.circle),
                child: Icon(inc ? Icons.south_west_rounded : Icons.north_east_rounded, color: col, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(s.accName(t['accId']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(money(toD(t['amount']), cur), style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 14.5)),
            ]),
          ),
        ));
      }
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: p.accent,
        foregroundColor: p.accentInk,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(pageRoute(QuickTxScreen(type: 'expense', accId: widget.accId))),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: body)),
      ]),
    );
  }
}

/// Account page ⋮ → Edit Account.
void _editAccountSheet(BuildContext context, J a) {
  final s = StoreScope.read(context);
  final id = '${a['id']}';
  final name = TextEditingController(text: '${a['name'] ?? ''}');
  final bal = TextEditingController(text: s.accBal(a).toStringAsFixed(2));
  String cur = '${a['currency'] ?? s.base}';
  final locked = s.hasRealTx(id);
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(c).viewInsets.bottom + 18),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Edit Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(hintText: 'Account name', prefixIcon: Icon(Icons.label_outline_rounded))),
            const SizedBox(height: 12),
            Material(
              color: p.fg.withOpacity(.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: locked
                    ? null
                    : () async {
                        final picked = await pickCurrency(c, cur);
                        if (picked != null) set(() => cur = picked);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(children: [
                    Icon(locked ? Icons.lock_outline_rounded : Icons.currency_exchange_rounded, size: 20, color: p.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$cur — ${currencyName(cur)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (locked) Text('Currency cannot be changed after transactions exist', style: TextStyle(color: p.muted, fontSize: 11.5)),
                      ]),
                    ),
                    if (!locked) Icon(Icons.chevron_right_rounded, color: p.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(prefixText: '${currencySymbol(cur)}  ', helperText: 'Enter your current account balance.'),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return set(() => err = 'Enter an account name.');
                    final b = double.tryParse(bal.text.replaceAll(',', '').trim()) ?? 0;
                    s.saveWallet(id: id, name: name.text.trim(), currency: cur, balance: b);
                    Navigator.pop(c);
                    toast(context, 'Wallet updated successfully');
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ]),
        ),
      );
    }),
  );
}

/// Account page ⋮ → Correct Balance: adds a correction entry for the difference.
void _correctBalanceSheet(BuildContext context, J a) {
  final s = StoreScope.read(context);
  final id = '${a['id']}';
  final cb = s.accBal(a);
  final ctl = TextEditingController();
  final reason = TextEditingController();
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final p = Palette.of(c);
      void save() {
        final v = double.tryParse(ctl.text.replaceAll(',', '').trim());
        if (v == null) return set(() => err = 'Enter the corrected balance.');
        final d = round2(v - cb);
        if (d.abs() > 0.004) {
          (s.data['txns'] as List).add(<String, dynamic>{
            'id': uid(), 'type': d > 0 ? 'income' : 'expense', 'kind': 'correction', 'accId': id, 'amount': d.abs(), 'date': today(), 'time': nowTime(),
            'note': reason.text.trim().isEmpty ? 'Balance corrected' : reason.text.trim(), 'tags': <dynamic>[],
          });
          s.commit();
        }
        Navigator.pop(c);
        toast(context, 'Balance corrected');
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(c).viewInsets.bottom + 18),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Correct Balance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Save', icon: Icon(Icons.check_rounded, color: p.accent), onPressed: save),
            ]),
            const SizedBox(height: 8),
            Text('Current Balance: ${cb.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Corrected Balance', border: UnderlineInputBorder(), filled: false),
            ),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason for Correction (Optional)', border: UnderlineInputBorder(), filled: false)),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: save, child: const Text('Save'))),
            ]),
          ]),
        ),
      );
    }),
  );
}

/// Add / edit a wallet: name, currency and current balance (same rules as the web app).
void showWalletSheet(BuildContext context, {J? existing}) {
  final s = StoreScope.read(context);
  final name = TextEditingController(text: existing?['name']?.toString() ?? '');
  final bal = TextEditingController(text: existing == null ? '' : s.accBal(existing).toStringAsFixed(2));
  String cur = (existing?['currency'] ?? s.base).toString();
  final locked = existing != null && s.hasRealTx('${existing['id']}');
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(existing == null ? 'Add Account' : 'Edit Account', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Account name')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(locked ? Icons.lock_outline : Icons.currency_exchange_rounded),
            label: Text('$cur — ${currencyName(cur)}'),
            onPressed: locked
                ? null
                : () async {
                    final picked = await pickCurrency(c, cur);
                    if (picked != null) set(() => cur = picked);
                  },
          ),
          if (locked) Text('Currency cannot be changed after transactions exist', style: TextStyle(color: Palette.of(c).muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: bal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: existing == null ? 'Opening balance' : 'Current balance', prefixText: '${currencySymbol(cur)} '),
          ),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: Palette.of(c).neg))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return set(() => err = 'Enter an account name.');
              final b = double.tryParse(bal.text.replaceAll(',', '').trim()) ?? 0;
              s.saveWallet(id: existing?['id']?.toString(), name: name.text.trim(), currency: cur, balance: b);
              Navigator.pop(c);
              toast(context, existing == null ? 'Account created' : 'Wallet updated successfully');
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    ),
  );
}

Future<String?> pickCurrency(BuildContext context, String current) {
  final s = StoreScope.read(context);
  final mine = <String>{s.base, ...s.accounts.map((a) => '${a['currency']}')};
  final list = [...kCurrencies]..sort((a, b) {
      final ma = mine.contains(a.code) ? 0 : 1, mb = mine.contains(b.code) ? 0 : 1;
      return ma != mb ? ma.compareTo(mb) : a.code.compareTo(b.code);
    });
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SizedBox(
      height: MediaQuery.of(c).size.height * .7,
      child: ListView(children: [
        for (final cu in list)
          ListTile(
            leading: SizedBox(width: 44, child: Text(cu.symbol, style: const TextStyle(fontWeight: FontWeight.w700))),
            title: Text('${cu.code} — ${cu.name}'),
            trailing: cu.code == current ? Icon(Icons.check_rounded, color: Palette.of(c).accent) : null,
            onTap: () => Navigator.pop(c, cu.code),
          ),
      ]),
    ),
  );
}

void _addChooser(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Wallet or bank account'),
          onTap: () {
            Navigator.pop(c);
            showWalletSheet(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.credit_card_rounded),
          title: const Text('Credit card'),
          onTap: () {
            Navigator.pop(c);
            showCardSheet(context);
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// Public entry to one account's transactions (used by the Home account tiles).
class AccountTxnsScreen extends StatelessWidget {
  const AccountTxnsScreen({super.key, required this.accId});
  final String accId;
  @override
  Widget build(BuildContext context) => _AccountTxns(accId: accId);
}
