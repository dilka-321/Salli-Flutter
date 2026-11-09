import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'budget_screens.dart';
import 'card_screen.dart';
import 'due_soon.dart';
import 'phone_notify.dart';
import 'productivity_screens.dart';
import 'quick_tx.dart';
import 'settings_screen.dart';
import 'sms_admin_screens.dart';
import '../core/round7.dart';
import 'analytics_screen.dart';
import 'reports_screen.dart';
import 'home_screen.dart';
import 'side_menu.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

/// Bottom bar: Home · Budget · (+) · Analytics · Reports — same layout as the web app.
class Shell extends StatefulWidget {
  const Shell({super.key});

  /// Lets any tab open the side menu.
  static final scaffoldKey = GlobalKey<ScaffoldState>();
  static void openMenu() => scaffoldKey.currentState?.openDrawer();
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    openNotice = (ctx, n) {
      final Widget? page = switch (n.scr) {
        'budget' => BudgetViewScreen(id: n.id),
        'card' => CardScreen(id: n.id),
        'todos' => const TodosScreen(),
        'sms' => const SmsDraftsScreen(),
        _ => pageForDue(n.scr, n.id),
      };
      if (page != null) Navigator.of(ctx).push(pageRoute(page));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final s = StoreScope.read(context);
      s.refreshLiveRates();
      PhoneNotify.I.start(s);
      await runAutoBackup(context);
    });
  }

  void _quickAdd() {
    HapticFeedback.mediumImpact();
    final p = Palette.of(context);
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Add New', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _QuickBtn(icon: Icons.south_west_rounded, label: 'Expense', color: p.neg, onTap: () => _open(c, 'expense'))),
              const SizedBox(width: 12),
              Expanded(child: _QuickBtn(icon: Icons.north_east_rounded, label: 'Income', color: p.pos, onTap: () => _open(c, 'income'))),
            ]),
            const SizedBox(height: 12),
            _QuickBtn(
              icon: Icons.swap_horiz_rounded,
              label: 'Transfer between accounts',
              color: p.accent,
              onTap: () {
                Navigator.pop(c);
                Navigator.of(context).push(pageRoute(const TransferEditScreen()));
              },
            ),
            const SizedBox(height: 12),
            Text('Loans, lendings, subscriptions, recurring expenses, installments, plans and assets are in the side menu (☰ on Home).',
                style: TextStyle(color: p.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }

  void _open(BuildContext sheet, String type) {
    Navigator.pop(sheet);
    Navigator.of(context).push(pageRoute(QuickTxScreen(type: type)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pages = [
      const HomeScreen(),
      const BudgetTab(),
      const AnalyticsTab(),
      const ReportsTab(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (Shell.scaffoldKey.currentState?.isDrawerOpen == true) {
          Shell.scaffoldKey.currentState?.closeDrawer();
          return;
        }
        if (tab != 0) {
          setState(() => tab = 0);
          return;
        }
        final exit = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you really want to exit the app?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Exit')),
            ],
          ),
        );
        if (exit == true) SystemNavigator.pop();
      },
      child: Scaffold(
      key: Shell.scaffoldKey,
      drawer: const SideMenu(),
      drawerEdgeDragWidth: tab == 0 ? 28 : 0,
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: child),
        ),
        child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(color: p.bg.withOpacity(.82), border: Border(top: BorderSide(color: p.line))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 70,
                child: Row(children: [
                  _NavBtn(icon: Icons.home_rounded, label: 'Home', on: tab == 0, onTap: () => _go(0)),
                  _NavBtn(icon: Icons.receipt_long_rounded, label: 'Budget', on: tab == 1, onTap: () => _go(1)),
                  SizedBox(
                    width: 84,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -14),
                        child: GestureDetector(
                          onTap: _quickAdd,
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(p.accent, Colors.white, .15)!, p.accent]),
                              border: Border.all(color: p.bg, width: 5),
                              boxShadow: [BoxShadow(color: p.accent.withOpacity(.45), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -6)],
                            ),
                            child: Icon(Icons.add_rounded, size: 32, color: p.accentInk),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavBtn(icon: Icons.bar_chart_rounded, label: 'Analytics', on: tab == 2, onTap: () => _go(2)),
                  _NavBtn(icon: Icons.description_rounded, label: 'Reports', on: tab == 3, onTap: () => _go(3)),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _go(int i) {
    if (i == tab) return;
    HapticFeedback.selectionClick();
    setState(() => tab = i);
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = on ? p.accent : p.muted;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(color: on ? p.accent.withOpacity(.16) : Colors.transparent, borderRadius: BorderRadius.circular(99)),
            child: AnimatedScale(scale: on ? 1.08 : 1, duration: const Duration(milliseconds: 260), child: Icon(icon, color: c, size: 25)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withOpacity(.15), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
