import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../core/currency.dart';
import '../core/ops.dart';
import '../core/store.dart';
import 'accounts_screen.dart';
import 'assets_screens.dart';
import 'card_screen.dart';
import 'categories_screen.dart';
import 'goals_screens.dart';
import 'installments_screens.dart';
import 'lendings_screens.dart';
import 'loan_analyzer.dart';
import 'loans_screens.dart';
import 'monthly_plan_screens.dart';
import 'ot_screens.dart';
import 'overview_screen.dart';
import 'productivity_screens.dart';
import 'recurring_screens.dart';
import 'settings_screen.dart';
import 'sms_admin_screens.dart';
import 'spending_plan_screens.dart';
import 'subs_screens.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

/// Side menu — same sections and order as the Salli web app drawer.
class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final name = '${s.settings['name'] ?? s.profile?['full_name'] ?? ''}'.trim();
    final email = s.user?.email ?? '${s.profile?['email'] ?? ''}';
    final extra = [s.profile?['phone'], s.profile?['country']].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    final blue = const Color(0xFF5B8DEF), purple = const Color(0xFF9B7BF0), orange = const Color(0xFFF2A33A), red = const Color(0xFFE5625E);

    void go(Widget page) {
      HapticFeedback.selectionClick();
      // Open the page first and close the menu behind it once the page has slid in,
      // so the two animations don't run at the same time (that caused the lag).
      final sc = Scaffold.maybeOf(context);
      final nav = Navigator.of(context);
      nav.push(pageRoute(page));
      Future.delayed(const Duration(milliseconds: 340), () {
        if (sc != null && sc.mounted && sc.isDrawerOpen) sc.closeDrawer();
      });
    }


    Widget item(String label, IconData icon, Color c, Widget Function() page, {bool later = false}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          minVerticalPadding: 10,
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(.35))),
            child: Icon(icon, color: c, size: 22),
          ),
          title: Text(label, style: TextStyle(fontSize: 16, color: later ? p.fg.withOpacity(.75) : null)),
          trailing: later ? Text('soon', style: TextStyle(color: p.muted, fontSize: 11.5)) : null,
          onTap: () => go(page()),
        );

    Widget sec(String t, Color c) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text(t, style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
          ]),
        );

    return Drawer(
      width: MediaQuery.of(context).size.width * .82,
      backgroundColor: p.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(26))),
      child: ListView(padding: EdgeInsets.zero, children: [
        // ---- profile header
        InkWell(
          onTap: () => go(const SettingsScreen()),
          child: Container(
            padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 18, 22, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(p.accent, Colors.black, .35)!, Color.lerp(p.accent, Colors.black, .6)!]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white.withOpacity(.85),
                  child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
                const Spacer(),
                Text(AppConfig.appName.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12, letterSpacing: 2.4, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Text(name.isEmpty ? 'Set up your profile' : name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              if (email.isNotEmpty) Text(email, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 13)),
              if (extra.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(extra, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 13))),
            ]),
          ),
        ),
        // ---- SMS card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            onTap: () => go(const SmsSetupScreen()),
            gradient: LinearGradient(colors: [Color.alphaBlend(purple.withOpacity(.16), p.card), p.card]),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: purple.withOpacity(.18), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.auto_awesome_rounded, color: purple)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SMS Automation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text('Auto-track expenses from SMS', style: TextStyle(fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
        sec('FINANCE', p.pos),
        item('My Accounts', Icons.account_balance_wallet_outlined, p.pos, () => const AccountsScreen()),
        item('Financial Overview', Icons.trending_up_rounded, blue, () => const OverviewScreen()),
        item('Credit Cards', Icons.credit_card_rounded, purple, () => const CardsListScreen()),
        item('Transfers', Icons.swap_horiz_rounded, orange, () => const TransfersScreen()),
        item('SMS Drafts', Icons.sms_outlined, p.pos, () => const SmsDraftsScreen()),
        item('SMS Parser', Icons.document_scanner_outlined, blue, () => const SmsParserScreen()),
        sec('PLANNING', orange),
        item('Monthly Plan', Icons.calendar_view_month_rounded, p.pos, () => const MonthlyPlansScreen()),
        item('Spending Plan', Icons.event_note_rounded, blue, () => const SpendingPlansScreen()),
        item('OT & Salary', Icons.work_history_outlined, p.pos, () => const OtScreen()),
        item('Subscriptions', Icons.subscriptions_outlined, orange, () => const SubsScreen()),
        item('Recurring Expenses', Icons.repeat_rounded, orange, () => const RecurringScreen()),
        sec('LOANS & ASSETS', red),
        item('Loans', Icons.account_balance_rounded, red, () => const LoansScreen()),
        item('Loan Analyzer', Icons.query_stats_rounded, red, () => const LoanAnalyzerScreen()),
        item('Lendings', Icons.back_hand_outlined, orange, () => const LendingsScreen()),
        item('My Assets', Icons.work_outline_rounded, p.pos, () => const AssetsScreen()),
        item('Installments', Icons.receipt_long_rounded, blue, () => const InstallmentsScreen()),
        sec('PRODUCTIVITY', blue),
        item('Goals', Icons.savings_outlined, p.pos, () => const GoalsScreen()),
        item('To-Do List', Icons.check_box_outlined, blue, () => const TodosScreen()),
        item('Priority Board', Icons.assignment_outlined, purple, () => const PrioritiesScreen()),
        sec('SETTINGS', purple),
        item('Categories', Icons.grid_view_rounded, purple, () => const CategoriesScreen()),
        item('Tags', Icons.sell_outlined, purple, () => const TagsScreen()),
        item('Account Setup', Icons.home_outlined, blue, () => const AccountSetupScreen()),
        item('Customize Dashboard', Icons.dashboard_customize_outlined, p.pos, () => const DashboardSetupScreen()),
        item('Backup & Restore', Icons.cloud_upload_outlined, p.pos, () => const BackupScreen()),
        item('Settings', Icons.settings_outlined, blue, () => const SettingsScreen()),
        if (s.profile?['role'] == 'admin') ...[
          sec('ADMINISTRATION', p.pos),
          item('Admin approvals', Icons.person_outline_rounded, blue, () => const AdminScreen()),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
          child: Text('Version ${AppConfig.version}', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
        ),
      ]),
    );
  }
}

/// Credit cards list (opens each card page).
class CardsListScreen extends StatelessWidget {
  const CardsListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.cards;
    return Scaffold(
      appBar: AppBar(title: const Text('Credit Cards'), actions: [
        IconButton(tooltip: 'Add card', icon: const Icon(Icons.add_circle_outline_rounded), onPressed: () => showCardSheet(context)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (L.isEmpty) ...[
          const EmptyNote('No credit cards yet', icon: Icons.credit_card_rounded),
          Center(child: FilledButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add credit card'), onPressed: () => showCardSheet(context))),
        ],
        for (final c in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassCard(
              onTap: () => Navigator.of(context).push(pageRoute(CardScreen(id: '${c['id']}'))),
              child: Row(children: [
                EmojiTile('💳', tint: p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Used ${money(s.cardUsed(c), '${c['currency'] ?? s.base}')}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Available', style: TextStyle(color: p.muted, fontSize: 12)),
                  Text(money(s.accBal(c), '${c['currency'] ?? s.base}'), style: TextStyle(fontWeight: FontWeight.w800, color: p.pos)),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}
