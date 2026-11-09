import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'categories_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Small building blocks shared by the Budget, Subscription, Recurring and Installment screens.

double? parseAmount(String s) => double.tryParse(s.replaceAll(',', '').trim());

String plainNum(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class AmountBox extends StatelessWidget {
  const AmountBox({super.key, required this.controller, required this.currency, this.label = 'Amount', this.autofocus = false, this.onChanged, this.color});
  final TextEditingController controller;
  final String currency, label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final head = color ?? p.accent;
    return GlassCard(
      gradient: LinearGradient(colors: [Color.alphaBlend(head.withOpacity(.22), p.card), p.card]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.muted)),
        Row(children: [
          Text(currencySymbol(currency), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.muted)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: '0.00', contentPadding: EdgeInsets.zero),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Account selector — horizontally scrolling cards with name and balance (same style everywhere).
/// [walletsOnly] hides credit cards (used where the web app shows wallet cards only).
class AccountChips extends StatelessWidget {
  const AccountChips({super.key, required this.value, required this.onChanged, this.walletsOnly = false, this.allowNone = false, this.exclude});
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool walletsOnly, allowNone;
  final String? exclude;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = (walletsOnly ? s.wallets : s.accounts).where((a) => a['id'] != exclude).toList();
    if (list.isEmpty) return Text('Create an account first', style: TextStyle(color: Palette.of(context).muted));
    return AccountCardsRow(
      items: [
        if (allowNone) (id: null, name: 'None', sub: 'No account', neg: false),
        for (final a in list) (id: '${a['id']}', name: '${a['name']}', sub: money(s.accBal(a), '${a['currency']}'), neg: s.accBal(a) < 0),
      ],
      value: value,
      onChanged: onChanged,
    );
  }
}

class AccountCardsRow extends StatefulWidget {
  const AccountCardsRow({super.key, required this.items, required this.value, required this.onChanged});
  final List<({String? id, String name, String sub, bool neg})> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  State<AccountCardsRow> createState() => _AccountCardsRowState();
}

class _AccountCardsRowState extends State<AccountCardsRow> {
  final _sc = ScrollController();
  static const _w = 150.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = widget.items.indexWhere((x) => x.id == widget.value);
      if (i > 1 && _sc.hasClients) _sc.jumpTo(((i - 1) * (_w + 10)).clamp(0, _sc.position.maxScrollExtent).toDouble());
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 78,
      child: ListView.separated(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final x = widget.items[i];
          final on = x.id == widget.value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onChanged(x.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _w,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: on ? p.accent.withOpacity(.14) : p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? p.accent : p.line, width: on ? 1.6 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Flexible(child: Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: on ? p.accent : null))),
                  if (on) ...[const SizedBox(width: 4), Icon(Icons.check_rounded, size: 18, color: p.accent)],
                ]),
                const SizedBox(height: 4),
                Text(x.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: x.neg ? p.neg : p.muted, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class DateButton extends StatelessWidget {
  const DateButton({super.key, required this.value, required this.onChanged, this.label});
  final String value;
  final String? label;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_rounded, size: 18),
      label: Text(label == null ? fmtDate(value) : '$label: ${fmtDate(value)}'),
      onPressed: () async {
        final d = await showDatePicker(context: context, initialDate: parseDate(value), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) onChanged(isoDate(d));
      },
    );
  }
}

/// Bottom sheet listing expense categories (with subcategories) — returns the chosen id.
Future<String?> pickCategory(BuildContext context, {String kind = 'expense', String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      final s = StoreScope.of(c);
      final p = Palette.of(c);
      final mains = s.categories.where((x) => x['kind'] == kind && x['parent'] == null).toList();
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Row(children: [
            const Expanded(child: Text('Select category', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            TextButton.icon(onPressed: () => showCategorySheet(c, kind: kind), icon: const Icon(Icons.add_rounded), label: const Text('New')),
          ]),
          for (final m in mains) ...[
            _catRow(c, p, m, current, false),
            for (final sub in s.categories.where((x) => x['parent'] == m['id'])) _catRow(c, p, sub, current, true),
          ],
        ]),
      );
    },
  );
}

Widget _catRow(BuildContext c, Palette p, J x, String? current, bool sub) => ListTile(
      contentPadding: EdgeInsets.only(left: sub ? 36 : 4, right: 4),
      leading: Text('${x['icon'] ?? '📦'}', style: TextStyle(fontSize: sub ? 20 : 24)),
      title: Text('${x['name']}', style: TextStyle(fontWeight: sub ? FontWeight.w500 : FontWeight.w700)),
      trailing: current == x['id'] ? Icon(Icons.check_circle_rounded, color: p.accent) : null,
      onTap: () => Navigator.pop(c, '${x['id']}'),
    );

/// Tappable field row: icon, small label, value, chevron.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.icon, required this.label, required this.value, this.onTap, this.muted = false});
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: p.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: muted ? p.muted : null)),
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.muted),
        ]),
      ),
    );
  }
}

/// Label/value row.
Widget kvRow(Palette p, String k, String v, {Color? color, bool bold = false, String? sub}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(color: bold ? null : p.muted, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            if (sub != null && sub.isNotEmpty) Text(sub, style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 10),
        Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );

/// Rounded progress bar: green → orange at 80 % → red at 100 %.
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.color, this.height = 9});
  final double value;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? (value >= 1 ? p.neg : value >= .8 ? p.warn : p.pos);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: height, color: c, backgroundColor: p.fg.withOpacity(.08)),
      ),
    );
  }
}

/// Circular "% used" ring.
class Ring extends StatelessWidget {
  const Ring(this.value, {super.key, required this.center, this.caption = 'used', this.color, this.size = 92});
  final double value;
  final String center, caption;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(value: v, strokeWidth: 9, strokeCap: StrokeCap.round, color: color ?? p.accent, backgroundColor: p.fg.withOpacity(.08)),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(caption, style: TextStyle(color: p.muted, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

/// Grid tile used on detail pages (icon, label, value).
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icon, required this.label, required this.value, this.color, this.valueColor});
  final IconData icon;
  final String label, value;
  final Color? color, valueColor;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? p.accent;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: c, size: 20),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 2),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor)),
      ]),
    );
  }
}

Widget tileGrid(List<Widget> tiles) => LayoutBuilder(builder: (_, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });

/// Letter avatar.
class LetterTile extends StatelessWidget {
  const LetterTile(this.text, {super.key, required this.color, this.size = 50});
  final String text;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(size * .32)),
        child: Text(text.isEmpty ? '?' : text.substring(0, 1).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * .42)),
      );
}

/// Standard "Make payment" sheet: amount, account, date, optional note. Returns null when cancelled.
Future<({double amount, String accId, String date, String note})?> showPaySheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required double amount,
  required String? accId,
  String? currencyLabel, // fixed currency for the amount (installments use the main currency)
  String date = '',
  String? note,
  bool walletsOnly = false,
  String button = 'Make Payment',
}) {
  final ctl = TextEditingController(text: amount > 0 ? plainNum(round2(amount)) : '');
  final noteCtl = note == null ? null : TextEditingController(text: note);
  var acc = accId;
  var d = date.isEmpty ? today() : date;
  String? err;
  return showModalBottomSheet<({double amount, String accId, String date, String note})>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final s = StoreScope.of(c);
      final p = Palette.of(c);
      final cur = currencyLabel ?? s.accCur(acc);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle, style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              AmountBox(controller: ctl, currency: cur, label: 'Amount ($cur)'),
              const SizedBox(height: 14),
              Text('PAID FROM', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              AccountChips(value: acc, walletsOnly: walletsOnly, onChanged: (v) => set(() => acc = v)),
              const SizedBox(height: 14),
              DateButton(value: d, label: 'Payment date', onChanged: (v) => set(() => d = v)),
              if (noteCtl != null) ...[
                const SizedBox(height: 12),
                TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'Note')),
              ],
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: TextStyle(color: p.neg))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final v = parseAmount(ctl.text) ?? 0;
                  if (v <= 0) return set(() => err = 'Enter an amount above zero.');
                  if (acc == null) return set(() => err = 'Choose an account.');
                  HapticFeedback.lightImpact();
                  Navigator.pop(c, (amount: v, accId: acc!, date: d, note: noteCtl?.text.trim() ?? ''));
                },
                child: Text(button),
              ),
            ]),
          ),
        ),
      );
    }),
  );
}

/// Popup menu button helper.
Widget moreMenu(List<(String, IconData, VoidCallback, bool)> items) => PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (i) => items[i].$3(),
      itemBuilder: (c) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(children: [
              Icon(items[i].$2, size: 20, color: items[i].$4 ? Palette.of(c).neg : null),
              const SizedBox(width: 12),
              Text(items[i].$1, style: TextStyle(color: items[i].$4 ? Palette.of(c).neg : null)),
            ]),
          ),
      ],
    );

String moneyB(AppStore s, num v) => money(v, s.base);
