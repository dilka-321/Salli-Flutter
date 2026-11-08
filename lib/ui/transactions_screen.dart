import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'tx_edit_screen.dart';
import 'widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String? month; // null = all time
  String mode = 'all'; // all | income | expense | cashin | cashout
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    var list = s.txns;
    if (month != null) list = list.where((t) => ym('${t['date']}') == month).toList();
    if (mode == 'income') list = list.where(s.isInc).toList();
    if (mode == 'expense') list = list.where(s.isExp).toList();
    if (mode == 'cashin') list = list.where(s.isCashIn).toList();
    if (mode == 'cashout') list = list.where(s.isCashOut).toList();
    if (q.isNotEmpty) {
      final k = q.toLowerCase();
      list = list.where((t) => '${s.txTitle(t)} ${t['note'] ?? ''} ${s.accName(t['accId'])} ${t['amount']}'.toLowerCase().contains(k)).toList();
    }
    final cur = month ?? ym(today());
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        TextField(
          decoration: InputDecoration(prefixIcon: Icon(Icons.search, color: p.muted), hintText: 'Search name, note, account or amount'),
          onChanged: (v) => setState(() => q = v.trim()),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(
            onPressed: () => setState(() => month = addMonthsYm(cur, -1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => month = month == null ? ym(today()) : null),
                child: Text(month == null ? 'All time' : fmtMonth(month!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => month = addMonthsYm(cur, 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          if (month != null) TextButton(onPressed: () => setState(() => month = null), child: const Text('All')),
        ]),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final m in const [['all', 'All'], ['income', 'Income'], ['expense', 'Expense'], ['cashin', 'Cash In'], ['cashout', 'Cash Out']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m[1]),
                  selected: mode == m[0],
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => mode = m[0]);
                  },
                ),
              ),
          ]),
        ),
        if (list.isEmpty) const EmptyNote('No transactions match.') else TxGroups(list: list, onOpen: (t) => showTxDetail(context, t)),
      ]),
    );
  }
}

/// Details of one transaction, with Edit / Delete for plain income and expense entries.
void showTxDetail(BuildContext context, J t) {
  final s = StoreScope.read(context);
  final p = Palette.of(context);
  final c = s.accCur(t['accId']);
  final inc = t['type'] == 'income';
  final editable = s.canEdit(t);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            EmojiTile(s.txIcon(t), size: 54),
            const SizedBox(width: 14),
            Expanded(child: Text(s.txTitle(t), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 16),
          Text(money(toD(t['amount']), c), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: inc ? p.pos : p.neg)),
          if (c != s.base) Text('≈ ${money(s.tBase(t), s.base)}', style: TextStyle(color: p.muted)),
          const SizedBox(height: 14),
          _kv(p, 'Type', inc ? 'Income' : 'Expense'),
          _kv(p, 'Account', s.accName(t['accId'])),
          _kv(p, 'Date', '${fmtDate('${t['date']}')}  ${fmtTime(t['time']?.toString())}'),
          if ('${t['note'] ?? ''}'.isNotEmpty) _kv(p, 'Note', '${t['note']}'),
          if (t['tags'] is List && (t['tags'] as List).isNotEmpty) _kv(p, 'Tags', (t['tags'] as List).join(', ')),
          const SizedBox(height: 16),
          if (editable)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.delete_outline, color: p.neg),
                  label: Text('Delete', style: TextStyle(color: p.neg)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: p.neg.withOpacity(.5))),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: sheet,
                      builder: (d) => AlertDialog(
                        title: const Text('Delete transaction?'),
                        content: const Text('This removes it and updates your account balance.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Delete', style: TextStyle(color: p.neg))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      s.deleteTx('${t['id']}');
                      if (sheet.mounted) Navigator.pop(sheet);
                      if (context.mounted) toast(context, 'Transaction deleted');
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.pop(sheet);
                    Navigator.of(context).push(pageRoute(TxEditScreen(type: '${t['type']}', existing: t)));
                  },
                ),
              ),
            ])
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.warn.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
              child: Text(
                'This entry belongs to a ${AppStore.kindInfo[t['kind']]?.$1.toLowerCase() ?? 'linked record'} (loan, transfer, subscription…). '
                'To keep everything linked correctly, edit or delete it in that section — in the Salli web app for now.',
                style: TextStyle(color: p.warn, fontSize: 13),
              ),
            ),
        ]),
      ),
    ),
  );
}

Widget _kv(Palette p, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(k, style: TextStyle(color: p.muted))),
        Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
