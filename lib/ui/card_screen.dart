import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/ops.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

/// Credit card details: available, used %, due date and minimum, monthly transactions, Pay Now.
class CardScreen extends StatefulWidget {
  const CardScreen({super.key, required this.id});
  final String id;
  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  String month = ym(today());

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final c = s.acc(widget.id);
    if (c == null) return Scaffold(appBar: AppBar(), body: const EmptyNote('Card not found'));
    final cur = '${c['currency']}';
    final avail = s.accBal(c);
    final limit = toD(c['limit']);
    final used = s.cardUsed(c);
    final pct = limit > 0 ? (used / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final list = s.txns.where((t) => t['accId'] == c['id'] && ym('${t['date']}') == month).toList();
    final months = List.generate(6, (i) => addMonthsYm(ym(today()), -i));
    return Scaffold(
      appBar: AppBar(
        title: Text('${c['name']}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') showCardSheet(context, existing: c);
              if (v == 'delete') {
                final n = s.txCount('${c['id']}');
                final ok = await confirmDialog(context, 'Delete card?', n > 0 ? 'This also deletes its $n transaction${n > 1 ? 's' : ''}. This can’t be undone.' : 'This can’t be undone.');
                if (ok) {
                  s.deleteAccount('${c['id']}');
                  if (context.mounted) {
                    Navigator.pop(context);
                    toast(context, 'Card deleted');
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit card')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: p.neg))),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton.icon(icon: const Icon(Icons.credit_score_rounded), label: const Text('Pay Now'), onPressed: () => showCardPay(context, c)),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(p.accent, Colors.black, .1)!, Color.lerp(p.accent, Colors.black, .55)!]),
            boxShadow: [BoxShadow(color: p.accent.withOpacity(.35), blurRadius: 30, offset: const Offset(0, 16), spreadRadius: -12)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.credit_card_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text('Credit Card · $cur', style: TextStyle(color: Colors.white.withOpacity(.85))),
            ]),
            const SizedBox(height: 18),
            Text('Available', style: TextStyle(color: Colors.white.withOpacity(.8))),
            FittedBox(fit: BoxFit.scaleDown, child: Text(money(avail, cur), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: Colors.white24, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text('${(pct * 100).round()}% used of ${money(limit, cur)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text(
              used > 0 ? 'Payment due ${fmtDate(s.cardDue(c))} · minimum ${money(s.cardMinimum(c), cur)}' : 'No payment due',
              style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 13),
            ),
          ]),
        ),
        const SectionTitle('Transactions'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final m in months)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(fmtMonth(m)), selected: m == month, onSelected: (_) => setState(() => month = m)),
              ),
          ]),
        ),
        if (list.isEmpty) const EmptyNote('No card transactions this month') else TxGroups(list: list, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
}

/// Pay the card from a wallet: Full / Minimum / custom amount.
void showCardPay(BuildContext context, J c) {
  final s = StoreScope.read(context);
  final cur = '${c['currency']}';
  final used = s.cardUsed(c);
  if (used <= 0) {
    toast(context, 'No payment due right now');
    return;
  }
  final amt = TextEditingController(text: used.toStringAsFixed(2));
  String? from = s.defaultAccId;
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sh) => StatefulBuilder(
      builder: (sh, set) {
        final p = Palette.of(sh);
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sh).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pay ${c['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Outstanding ${money(used, cur)}', style: TextStyle(color: p.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ActionChip(label: Text('Full ${money(used, cur)}'), onPressed: () => set(() => amt.text = used.toStringAsFixed(2))),
              ActionChip(label: const Text('Minimum'), onPressed: () => set(() => amt.text = round2(s.cardMinimum(c)).toStringAsFixed(2))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: amt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Amount', prefixText: '${currencySymbol(cur)} ')),
            const SizedBox(height: 12),
            Text('Pay from', style: TextStyle(color: p.muted)),
            const SizedBox(height: 6),
            AccountChips(value: from, walletsOnly: true, onChanged: (v) => set(() => from = v ?? from)),
            if (from != null && s.accCur(from) != cur && (double.tryParse(amt.text) ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Paid from a ${s.accCur(from)} account — converted at the app rate. For your bank’s rate use Transfer instead.', style: TextStyle(color: p.muted, fontSize: 12)),
              ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: p.neg))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(amt.text.replaceAll(',', '').trim()) ?? 0;
                if (v <= 0) return set(() => err = 'Enter an amount above zero.');
                if (from == null) return set(() => err = 'Choose an account to pay from.');
                HapticFeedback.lightImpact();
                s.payCard(cardId: '${c['id']}', fromId: from!, amount: v);
                Navigator.pop(sh);
                toast(context, 'Payment recorded');
              },
              child: const Text('Make Payment'),
            ),
          ]),
        );
      },
    ),
  );
}

/// Add / edit credit card (same fields and rules as the web app).
void showCardSheet(BuildContext context, {J? existing}) {
  final s = StoreScope.read(context);
  final c = existing;
  final locked = c != null && s.hasRealTx('${c['id']}');
  final name = TextEditingController(text: c?['name']?.toString() ?? '');
  final limit = TextEditingController(text: c == null ? '' : '${c['limit'] ?? ''}');
  final avail = TextEditingController(text: c == null ? '' : s.accBal(c).toStringAsFixed(2));
  final interest = TextEditingController(text: c == null ? '' : '${c['interest'] ?? ''}');
  final minPay = TextEditingController(text: c == null ? '5' : '${c['minPay'] ?? 5}');
  String cur = (c?['currency'] ?? s.base).toString();
  int bill = c == null ? 1 : (int.tryParse('${c['billingDay']}') ?? 1);
  int due = c == null ? 25 : (int.tryParse('${c['dueDay']}') ?? 25);
  bool inc = c == null ? true : c['includeCredit'] != false;
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sh) => StatefulBuilder(builder: (sh, set) {
      final p = Palette.of(sh);
      final grace = ((due - bill + 31) % 31) == 0 ? 31 : (due - bill + 31) % 31;
      Future<void> pickDay(bool isBill) async {
        final d = await showDialog<int>(
          context: sh,
          builder: (dc) => AlertDialog(
            title: Text(isBill ? 'Billing Start Day' : 'Payment Due Day'),
            content: SizedBox(
              width: 300,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var i = 1; i <= 31; i++)
                    InkWell(
                      onTap: () => Navigator.pop(dc, i),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (isBill ? bill : due) == i ? p.accent : p.card2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$i', style: TextStyle(color: (isBill ? bill : due) == i ? p.accentInk : p.fg, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        if (d != null) {
          set(() {
            if (isBill) {
              bill = d;
            } else {
              due = d;
            }
          });
        }
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sh).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c == null ? 'Add Credit Card' : 'Edit Credit Card', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Card name')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(locked ? Icons.lock_outline : Icons.currency_exchange_rounded),
              label: Text('$cur — ${currencyName(cur)}'),
              onPressed: locked
                  ? null
                  : () async {
                      final x = await pickCurrency(sh, cur);
                      if (x != null) set(() => cur = x);
                    },
            ),
            if (locked) Text('Currency cannot be changed after transactions exist', style: TextStyle(color: p.muted, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(controller: limit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Credit limit', prefixText: '${currencySymbol(cur)} ')),
            const SizedBox(height: 12),
            TextField(controller: avail, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Available to spend', prefixText: '${currencySymbol(cur)} ')),
            Text('Enter the amount you can currently spend with this card.', style: TextStyle(color: p.muted, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => pickDay(true), child: Text('Billing day: $bill'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => pickDay(false), child: Text('Due day: $due'))),
            ]),
            const SizedBox(height: 6),
            Text('Grace period: $grace days', style: TextStyle(color: p.pos, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: interest, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest % / year'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: minPay, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum payment %'))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: inc,
              onChanged: (v) => set(() => inc = v),
              title: const Text('Include card balance in available balance', style: TextStyle(fontSize: 14)),
            ),
            if (err != null) Text(err!, style: TextStyle(color: p.neg)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final lim = double.tryParse(limit.text.replaceAll(',', '').trim()) ?? 0;
                final av = double.tryParse(avail.text.replaceAll(',', '').trim());
                if (name.text.trim().isEmpty) return set(() => err = 'Enter a card name.');
                if (lim <= 0) return set(() => err = 'Enter the credit limit.');
                if (av == null) return set(() => err = 'Enter the available amount.');
                s.saveCard(
                  id: c?['id']?.toString(),
                  name: name.text.trim(),
                  currency: cur,
                  limit: lim,
                  available: av,
                  billingDay: bill,
                  dueDay: due,
                  interest: double.tryParse(interest.text.trim()) ?? 0,
                  minPay: double.tryParse(minPay.text.trim()) ?? 5,
                  includeCredit: inc,
                );
                Navigator.pop(sh);
                toast(context, c == null ? 'Credit card added' : 'Wallet updated successfully');
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      );
    }),
  );
}

/// Open the transfer screen with the card pre-filled as the receiving account.
void openCardTransfer(BuildContext context, String cardId) {
  Navigator.of(context).push(pageRoute(TransferEditScreen(presetTo: cardId)));
}
