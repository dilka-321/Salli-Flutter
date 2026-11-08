import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/loans.dart';
import 'installments_screens.dart';
import 'lendings_screens.dart';
import 'loans_screens.dart';
import 'recurring_screens.dart';
import 'subs_screens.dart';
import 'theme.dart';
import 'widgets.dart';

Widget pageForDue(String scr, String id) => switch (scr) {
      'loan' => LoanDetailScreen(id: id),
      'lending' => LendingDetailScreen(id: id),
      'sub' => SubDetailScreen(id: id),
      'rec' => RecDetailScreen(id: id),
      _ => InstDetailScreen(id: id),
    };

/// Home "DUE SOON" card — everything overdue or due within a week (loans, money to collect, subscriptions, recurring, installments).
class DueSoonCard extends StatelessWidget {
  const DueSoonCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.dueItems();
    if (L.isEmpty) return const SizedBox.shrink();
    String when(int d) => d < 0 ? 'Payment overdue by ${-d} day${d < -1 ? 's' : ''}' : d == 0 ? 'Due today' : d == 1 ? 'Due tomorrow' : 'Due in $d days';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 8),
        gradient: LinearGradient(colors: [Color.alphaBlend(p.neg.withOpacity(.12), p.card), p.card]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: p.neg, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('DUE SOON', style: TextStyle(color: p.neg, fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 6),
          for (final d in L.take(6))
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(pageRoute(pageForDue(d.scr, d.id)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 4, height: 38, decoration: BoxDecoration(color: d.days < 0 ? p.neg : p.warn, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(d.amt, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      Text('${when(d.days)} · ${d.kind}', style: TextStyle(color: d.days < 0 ? p.neg : p.muted, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                    onPressed: () => s.hideDue(d.key),
                  ),
                ]),
              ),
            ),
          if (L.length > 6) Padding(padding: const EdgeInsets.fromLTRB(4, 4, 0, 6), child: Text('+${L.length - 6} more due', style: TextStyle(color: p.muted, fontSize: 12))),
        ]),
      ),
    );
  }
}
