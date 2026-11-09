import 'package:flutter/material.dart';

import '../core/currency.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'card_screen.dart';
import 'due_soon.dart';
import 'home_widgets.dart';
import '../core/round6.dart';
import '../core/round7.dart';
import 'settings_screen.dart';
import 'shell.dart';
import 'theme.dart';
import 'transactions_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final name = ((s.profile?['full_name'] ?? s.settings['name'] ?? '').toString().trim());
    final first = name.isEmpty ? 'there' : name.split(' ').first;
    final mk = ym(today());
    final st = s.stats(monthStart(mk), monthEnd(mk));
    final net = st.cin - st.cout;
    final recent = s.txns.toList()..sort((a, b) => ('${b['date']}${b['time'] ?? ''}').compareTo('${a['date']}${a['time'] ?? ''}'));
    final top = recent.take(12).toList();

    return Scaffold(
      body: RefreshIndicator(
        color: p.accent,
        onRefresh: () async {
          if (s.dirty) {
            await s.syncNow();
          } else {
            await s.pullIfNewer();
          }
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 72,
            backgroundColor: p.bg.withOpacity(.92),
            automaticallyImplyLeading: false,
            leading: IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu_rounded, size: 28), onPressed: Shell.openMenu),
            titleSpacing: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi, $first', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              Text('Welcome to Salli', style: TextStyle(fontSize: 13.5, color: p.muted, fontWeight: FontWeight.w400)),
            ]),
            actions: [
              Builder(builder: (_) {
                final n = s.notifications().length;
                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.of(context).push(pageRoute(const NotificationsScreen())),
                  icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications_none_rounded, size: 27)),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(pageRoute(const SettingsScreen())),
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: p.accent.withOpacity(.2),
                    child: Text(first.isEmpty ? 'S' : first[0].toUpperCase(), style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 19)),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
            sliver: SliverList.list(children: [
              _SyncChip(text: s.syncStatus, dirty: s.dirty),
              const SizedBox(height: 10),
              for (final w in s.widgetOrder)
                if (!s.hiddenWidgets.contains(w))
                  (switch (w) {
                    'dues' => const DueSoonCard(),
                    'balance' => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color.alphaBlend(p.accent.withOpacity(.16), p.card), p.card],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Net Cash Flow', style: TextStyle(color: p.muted, fontSize: 15)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(net, s.base), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: net < 0 ? p.neg : p.fg, letterSpacing: -.5)),
                  ),
                  const SizedBox(height: 4),
                  Text('${fmtDate(monthStart(mk))} – ${fmtDate(monthEnd(mk))}', style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _Mini(label: 'Cash In', value: money(st.cin, s.base), color: p.pos, icon: Icons.arrow_upward_rounded, sub: 'Income ${money(st.inc, s.base)}')),
                    const SizedBox(width: 12),
                    Expanded(child: _Mini(label: 'Cash Out', value: money(st.cout, s.base), color: p.neg, icon: Icons.arrow_downward_rounded, sub: 'Expense ${money(st.exp, s.base)}')),
                  ]),
                ]),
              ),
                      ),
                    'accounts' => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _accountsCard(context, s, p),
                          const SizedBox(height: 12),
                          _AccountTiles(),
                        ]),
                      ),
                    'recent' => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Recent Transactions', action: 'See all', onAction: () => Navigator.of(context).push(pageRoute(const TransactionsScreen()))),
              if (top.isEmpty)
                const EmptyNote('No transactions yet. Tap + to add your first one.')
              else
                TxGroups(list: top, onOpen: (t) => showTxDetail(context, t)),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(pageRoute(const TransactionsScreen())),
                child: const Text('See All Transactions'),
              ),
                        ]),
                      ),
                    _ => HomeWidget(id: w),
                  }),
            ]),
          ),
        ]),
      ),
    );
  }
}


Widget _accountsCard(BuildContext context, AppStore s, Palette p) => GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(const AccountsScreen())),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('My Accounts', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                    Text('See all', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  Text('All Accounts Balance', style: TextStyle(color: p.muted, fontSize: 13)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(s.totalBalance, s.base), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                  ),
                  if (s.cards.isNotEmpty) ...[
                    Divider(height: 22, color: p.line),
                    Row(children: [
                      Icon(Icons.credit_card_rounded, size: 18, color: p.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Credit cards available', style: TextStyle(color: p.muted))),
                      Text(money(s.cards.fold(0.0, (a, c) => a + s.conv(s.accBal(c), '${c['currency']}', s.base)), s.base), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ]),
              );

/// Horizontally scrolling account tiles under My Accounts (tap to see that account's transactions).
class _AccountTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.accounts.where((a) => a['include'] != false || s.isCard(a)).toList();
    if (L.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: L.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = L[i];
          final bal = s.accBal(a);
          final neg = bal < 0;
          final card = s.isCard(a);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(pageRoute(card ? CardScreen(id: '${a['id']}') : AccountTxnsScreen(accId: '${a['id']}'))),
            child: Container(
              width: 128,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: neg ? p.warn.withOpacity(.7) : p.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: p.fg.withOpacity(.07), borderRadius: BorderRadius.circular(10)), child: Icon(card ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined, size: 19, color: p.muted)),
                const Spacer(),
                Row(children: [
                  if (neg) ...[Icon(Icons.warning_amber_rounded, size: 13, color: p.warn), const SizedBox(width: 3)],
                  Expanded(child: Text('${a['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5))),
                ]),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money(bal, '${a['currency']}'), style: TextStyle(fontWeight: FontWeight.w800, color: neg ? p.neg : null))),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.text, required this.dirty});
  final String text;
  final bool dirty;
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final p = Palette.of(context);
    final c = dirty ? p.warn : p.pos;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, size: 15, color: c),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.color, required this.icon, required this.sub});
  final String label, value, sub;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card2, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withOpacity(.16), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: p.muted, fontSize: 13)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 11.5)),
      ]),
    );
  }
}
