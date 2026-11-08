import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';

/// Gives every screen access to the store and rebuilds it on changes.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);
  static AppStore of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext c) => c.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.gradient, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? p.card : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(dark ? .5 : .07), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -14),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return box;
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: TextStyle(color: p.accent, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class EmojiTile extends StatelessWidget {
  const EmojiTile(this.emoji, {super.key, this.tint, this.size = 46});
  final String emoji;
  final Color? tint;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (tint ?? p.fg).withOpacity(.08),
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: p.line),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * .45)),
    );
  }
}

/// One transaction row, same layout as the web app list.
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.t, this.onTap});
  final J t;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final inc = t['type'] == 'income';
    final c = s.accCur(t['accId']);
    final note = (t['note'] ?? '').toString();
    final color = inc ? p.pos : p.neg;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          EmojiTile(s.txIcon(t), tint: inc ? p.pos : p.neg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.txTitle(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(s.accName(t['accId']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
              if (note.isNotEmpty) Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(s.tBase(t), s.base), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15.5, fontFeatures: const [FontFeature.tabularFigures()])),
            if (c != s.base) Text(money(toD(t['amount']), c), style: TextStyle(color: color.withOpacity(.75), fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

/// Transactions grouped by day with the day's in/out totals (like the web dashboard).
class TxGroups extends StatelessWidget {
  const TxGroups({super.key, required this.list, required this.onOpen});
  final List<J> list;
  final void Function(J t) onOpen;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final sorted = [...list]..sort((a, b) => ('${b['date']}${b['time'] ?? ''}').compareTo('${a['date']}${a['time'] ?? ''}'));
    final groups = <String, List<J>>{};
    for (final t in sorted) {
      groups.putIfAbsent('${t['date']}', () => []).add(t);
    }
    final td = today();
    final yd = isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final children = <Widget>[];
    groups.forEach((d, arr) {
      final inn = arr.where((t) => t['type'] == 'income').fold(0.0, (a, t) => a + s.tBase(t));
      final out = arr.where((t) => t['type'] != 'income').fold(0.0, (a, t) => a + s.tBase(t));
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Row(children: [
          Text(d == td ? 'Today' : d == yd ? 'Yesterday' : fmtDate(d), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: p.accent.withOpacity(.14), borderRadius: BorderRadius.circular(99)),
            child: Text(weekday(d), style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (inn > 0) Text('↑ ${money(inn, s.base)}', style: TextStyle(color: p.pos, fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (inn > 0 && out > 0) const SizedBox(width: 8),
          if (out > 0) Text('↓ ${money(out, s.base)}', style: TextStyle(color: p.neg, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ));
      children.add(GlassCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < arr.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.line),
            TxTile(t: arr[i], onTap: () => onOpen(arr[i])),
          ]
        ]),
      ));
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(children: [
        Icon(icon, size: 42, color: p.muted),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
      ]),
    );
  }
}

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

/// Smooth slide-and-fade route used for every page.
Route<T> pageRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, sa, child) {
        final curve = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        final out = CurvedAnimation(parent: sa, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(.12, 0), end: Offset.zero).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween(begin: Offset.zero, end: const Offset(-.06, 0)).animate(out),
              child: child,
            ),
          ),
        );
      },
    );
