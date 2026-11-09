import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/loans.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'widgets.dart';

const _gIcons = <String, IconData>{
  'Bank': Icons.account_balance_rounded,
  'Cash': Icons.payments_outlined,
  'Lending': Icons.back_hand_outlined,
  'Fixed Assets': Icons.home_outlined,
  'Fixed Deposits': Icons.receipt_long_rounded,
  'Saving Goals': Icons.savings_outlined,
  'Investment': Icons.trending_up_rounded,
  'Credit Card': Icons.credit_card_rounded,
  'Loan': Icons.receipt_outlined,
  'Installment': Icons.receipt_long_rounded,
  'Overdraft': Icons.warning_amber_rounded,
  'Other Liability': Icons.warning_amber_rounded,
};

/// Financial Overview — net worth, balance sheet, assets vs liabilities, insights (same figures as the web app).
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final n = s.netWorthDetail();
    final mk = ym(today());
    final st = s.stats(monthStart(mk), monthEnd(mk));
    final hl = n.L == 0 || n.ratio < .3 ? ('Healthy', p.pos) : n.ratio < .6 ? ('Stable', p.warn) : ('At risk', p.neg);
    final tot = n.A + n.L;
    final pa = tot != 0 ? n.A / tot : 1.0;
    String ch(double v) => '${v >= 0 ? '↑ +' : '↓ '}${v.toStringAsFixed(1)}%';
    final text = 'Financial Overview\nNet worth: ${moneyB(s, n.net)}\nTotal assets: ${moneyB(s, n.A)}\nTotal liabilities: ${moneyB(s, n.L)}\nLiabilities are ${(n.ratio * 100).toStringAsFixed(1)}% of assets.\n\nInsights:\n${n.ins.map((x) => '- ${x.text}').join('\n')}';
    Widget group(NwGroup g, bool liab) {
      final showItems = !liab && (g.items.length > 1 || g.name == 'Bank');
      final col = liab ? p.neg : p.pos;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Icon(_gIcons[g.name] ?? Icons.work_outline_rounded, size: 18, color: col)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (showItems) Text('${g.items.length} ${g.name == 'Bank' ? 'accounts' : 'items'}', style: TextStyle(color: p.muted, fontSize: 12)),
                if (liab) Text(g.items.map((x) => x.name).join(', '), style: TextStyle(color: p.muted, fontSize: 12)),
              ]),
            ),
            Text(moneyB(s, g.v), style: TextStyle(fontWeight: FontWeight.w800, color: col)),
          ]),
          if (showItems)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 2),
              child: Column(children: [
                for (final x in g.items)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(x.name, style: TextStyle(color: p.muted, fontSize: 13))), Text(moneyB(s, x.v), style: TextStyle(color: p.muted, fontSize: 13))])),
              ]),
            ),
        ]),
      );
    }

    IconData insIcon(String i) => i == 'bank' ? Icons.account_balance_rounded : i == 'pie' ? Icons.pie_chart_outline_rounded : Icons.lightbulb_outline_rounded;
    Color insCol(String c) => c == 'red' ? p.neg : c == 'orange' ? p.warn : p.accent;

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Overview'), actions: [
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () async {
            try {
              await SharePlus.instance.share(ShareParams(text: text, subject: 'Financial Overview'));
            } catch (_) {
              Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) toast(context, 'Summary copied — paste it anywhere to share');
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(p.pos.withOpacity(.16), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('NET WORTH', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
              Badge2('This month', color: p.muted),
            ]),
            const SizedBox(height: 6),
            Text(moneyB(s, n.net), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.pos)),
            const SizedBox(height: 6),
            Row(children: [Text('Your financial position ', style: TextStyle(color: p.muted, fontSize: 13)), Badge2('● ${hl.$1}', color: hl.$2)]),
            const SizedBox(height: 8),
            Text('Net savings this month: ${moneyB(s, st.cin - st.cout)}', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        tileGrid([
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TOTAL ASSETS', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w800)), FittedBox(child: Text(moneyB(s, n.A), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))), const SizedBox(height: 6), Badge2(ch(n.chA), color: p.pos)])),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TOTAL LIABILITIES', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w800)), FittedBox(child: Text(moneyB(s, n.L), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))), const SizedBox(height: 6), Badge2(ch(n.chL), color: p.neg)])),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(children: [Text('BALANCE SHEET', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4)), const SizedBox(width: 10), Expanded(child: Divider(color: p.line))]),
        ),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.account_balance_wallet_outlined, color: p.pos),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TOTAL ASSETS', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w800)), Text(moneyB(s, n.A), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text('${ch(n.chA)} this period', style: TextStyle(color: p.pos, fontSize: 12))])),
            ]),
            Divider(color: p.line),
            if (n.groups.isEmpty) Text('No assets yet.', style: TextStyle(color: p.muted)),
            for (final g in n.groups) group(g, false),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.account_balance_rounded, color: p.neg),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TOTAL LIABILITIES', style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w800)), Text(moneyB(s, n.L), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text('${ch(n.chL)} this period', style: TextStyle(color: p.neg, fontSize: 12))])),
            ]),
            Divider(color: p.line),
            if (n.lgroups.isEmpty) Text('No liabilities.', style: TextStyle(color: p.muted)),
            for (final g in n.lgroups) group(g, true),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            Ring(pa, center: '${(pa * 100).round()}%', caption: 'Assets', color: p.pos, size: 150),
            const SizedBox(height: 14),
            Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: p.pos, shape: BoxShape.circle)), const SizedBox(width: 8), const Expanded(child: Text('Assets')), Text(moneyB(s, n.A), style: TextStyle(color: p.pos, fontWeight: FontWeight.w800)), Text('  ${(pa * 100).toStringAsFixed(1)}%', style: TextStyle(color: p.muted, fontSize: 12))]),
            const SizedBox(height: 6),
            ProgressBar(pa, color: p.pos),
            const SizedBox(height: 10),
            Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: p.neg, shape: BoxShape.circle)), const SizedBox(width: 8), const Expanded(child: Text('Liabilities')), Text(moneyB(s, n.L), style: TextStyle(color: p.neg, fontWeight: FontWeight.w800)), Text('  ${tot != 0 ? (n.L / tot * 100).toStringAsFixed(1) : '0.0'}%', style: TextStyle(color: p.muted, fontSize: 12))]),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(Icons.auto_awesome_rounded, color: p.pos), const SizedBox(width: 8), const Text('Financial Insights', style: TextStyle(fontWeight: FontWeight.w800))]),
            for (final x in n.ins)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.fg.withOpacity(.04), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [Icon(insIcon(x.icon), color: insCol(x.color), size: 20), const SizedBox(width: 10), Expanded(child: Text(x.text, style: const TextStyle(fontSize: 13.5)))]),
              ),
          ]),
        ),
      ]),
    );
  }
}
