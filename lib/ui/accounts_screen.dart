import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/currency_table.dart';
import '../core/ops.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'card_screen.dart';
import 'transactions_screen.dart';
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withOpacity(.18), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All Accounts Balance', style: TextStyle(color: p.muted)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(money(s.totalBalance, s.base), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
            Text('${s.wallets.length} accounts · main currency ${s.base}', style: TextStyle(color: p.muted, fontSize: 13)),
          ]),
        ),
        const SectionTitle('Wallets & bank accounts'),
        if (s.wallets.isEmpty) const EmptyNote('No accounts yet. Tap + to add one.'),
        for (final a in s.wallets) ...[
          _AccCard(a: a),
          const SizedBox(height: 10),
        ],
        ...[
          SectionTitle('Credit cards', action: 'Add card', onAction: () => showCardSheet(context)),
          if (s.cards.isEmpty) const EmptyNote('No credit cards added.', icon: Icons.credit_card_off_outlined),
          for (final a in s.cards) ...[
            _AccCard(a: a),
            const SizedBox(height: 10),
          ],
        ],
      ]),
    );
  }
}

class _AccCard extends StatelessWidget {
  const _AccCard({required this.a});
  final J a;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cur = '${a['currency']}';
    final bal = s.accBal(a);
    final card = s.isCard(a);
    final limit = toD(a['limit']);
    return GlassCard(
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
      ]),
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

class _AccountTxns extends StatelessWidget {
  const _AccountTxns({required this.accId});
  final String accId;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.txns.where((t) => t['accId'] == accId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s.accName(accId))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        if (list.isEmpty) const EmptyNote('No transactions in this account yet.') else TxGroups(list: list, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
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
