import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/round7.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'theme.dart';
import 'tx_edit_screen.dart';
import 'widgets.dart';

// ======================================================================= SMS automation
class SmsSetupScreen extends StatelessWidget {
  const SmsSetupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    const purple = Color(0xFF9B7BF0);
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Automation')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          gradient: LinearGradient(colors: [Color.alphaBlend(purple.withOpacity(.16), p.card), p.card]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_rounded, color: purple, size: 34),
            const SizedBox(height: 8),
            const Text('Auto-track bank SMS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Your bank already texts you for every purchase, transfer and salary credit. Paste those messages into the SMS Parser and Salli turns each one into a ready-to-review draft with amount, merchant, category and account filled in.', style: TextStyle(color: p.muted)),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            for (final x in const [
              ('1', 'Copy bank SMS', 'Open your messages app and copy one or more bank messages.'),
              ('2', 'Paste into SMS Parser', 'OTPs and promotions are skipped, account numbers are masked.'),
              ('3', 'Review & save', 'Drafts land in SMS Drafts. Tap Save, and it’s recorded.'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 15, backgroundColor: p.pos.withOpacity(.15), child: Text(x.$1, style: TextStyle(color: p.pos, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.$2, style: const TextStyle(fontWeight: FontWeight.w800)), Text(x.$3, style: TextStyle(color: p.muted, fontSize: 13))])),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, color: p.muted),
            const SizedBox(width: 10),
            Expanded(child: Text('Everything is processed on this phone. Salli does not ask for permission to read your SMS inbox — messages are pasted in, so nothing is read without you choosing it.', style: TextStyle(color: p.muted, fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => Navigator.of(context).push(pageRoute(const SmsParserScreen())), child: const Text('Open SMS Parser')),
      ]),
    );
  }
}

class SmsParserScreen extends StatefulWidget {
  const SmsParserScreen({super.key});
  @override
  State<SmsParserScreen> createState() => _SmsParserScreenState();
}

class _SmsParserScreenState extends State<SmsParserScreen> {
  final ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _sample() {
    final d = today();
    final dd = '${d.substring(8)}/${d.substring(5, 7)}';
    ctl.text = 'BOC: LKR 3,450.00 debited from A/C XXXX4521 at KEELLS SUPER on $dd. Avl Bal LKR 52,310.00\n\nYour OTP for online payment is 482910. Do not share.\n\nCOMBANK: LKR 145,000.00 credited to A/C ****8812 SALARY from ABC PVT LTD on $dd.\n\nHNB: Purchase of Rs 1,890.00 at DIALOG AXIATA on card ending 7781 was successful.\n\nMEGA SALE! 40% off at partner stores this weekend. Click to claim.';
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Parser')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        TextField(
          controller: ctl,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(labelText: 'Paste bank SMS (separate messages with a blank line)', alignLabelWithHint: true, hintText: 'e.g. LKR 3,450.00 debited from A/C XXXX4521 at KEELLS SUPER on 30/10/2026. Avl Bal LKR 52,310.00'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
            icon: const Icon(Icons.content_paste_rounded),
            label: const Text('Paste'),
            onPressed: () async {
              final d = await Clipboard.getData('text/plain');
              if (d?.text != null) ctl.text = ctl.text.isEmpty ? d!.text! : '${ctl.text}\n\n${d!.text!}';
            },
          ),
          TextButton(onPressed: _sample, child: const Text('Try sample')),
        ]),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: () {
            final (ok, sk) = s.addSmsDrafts(ctl.text);
            if (ok > 0) {
              ctl.clear();
              Navigator.of(context).pushReplacement(pageRoute(const SmsDraftsScreen()));
              toast(context, '$ok draft${ok > 1 ? 's' : ''} created${sk.isNotEmpty ? ' · ${sk.length} skipped' : ''}');
            } else {
              toast(context, sk.isNotEmpty ? 'Nothing to add · skipped ${sk.toSet().join(', ')}' : 'Paste at least one message');
            }
          },
          child: const Text('Parse Messages'),
        ),
        const SizedBox(height: 10),
        Text('Recognised: amounts in LKR/Rs/USD/MVR/INR, debit and credit keywords, merchant names, dates, and 30+ bank names including BOC, ComBank, HNB, Sampath, NDB, Seylan and NTB.', style: TextStyle(color: p.muted, fontSize: 12.5)),
      ]),
    );
  }
}

class SmsDraftsScreen extends StatelessWidget {
  const SmsDraftsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.smsDrafts;
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Drafts'), actions: [
        if (L.length > 1)
          TextButton(
            onPressed: () {
              final n = s.saveAllSmsDrafts();
              toast(context, '$n transactions saved');
            },
            child: const Text('Save all'),
          ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (L.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: GlassCard(
              child: Column(children: [
                Icon(Icons.shield_outlined, color: p.pos, size: 36),
                const SizedBox(height: 8),
                const Text('No SMS drafts', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Paste bank messages into the SMS Parser to create drafts here.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                const SizedBox(height: 10),
                FilledButton(onPressed: () => Navigator.of(context).push(pageRoute(const SmsParserScreen())), child: const Text('Open SMS Parser')),
              ]),
            ),
          ),
        for (final d in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  EmojiTile('${s.cat(d['catId']?.toString())?['icon'] ?? '💸'}', tint: d['type'] == 'income' ? p.pos : p.neg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${'${d['merchant'] ?? ''}'.isNotEmpty ? d['merchant'] : s.cat(d['catId']?.toString())?['name'] ?? 'Bank transaction'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${s.cat(d['catId']?.toString())?['name'] ?? ''} · ${s.accName(d['accId'])} · ${fmtDate('${d['date']}')}', style: TextStyle(color: p.muted, fontSize: 12)),
                    ]),
                  ),
                  Text(money(toD(d['amount']), s.accCur(d['accId']?.toString())), style: TextStyle(fontWeight: FontWeight.w800, color: d['type'] == 'income' ? p.pos : p.neg)),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: p.fg.withOpacity(.05), borderRadius: BorderRadius.circular(8)),
                  child: Text('${d['raw']}', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: p.muted)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        s.removeSmsDraft('${d['id']}');
                        Navigator.of(context).push(pageRoute(TxEditScreen(type: '${d['type']}', draft: {'amount': d['amount'], 'catId': d['catId'], 'accId': d['accId'], 'date': d['date'], 'note': d['merchant']})));
                      },
                      child: const Text('Review & Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(onPressed: () => s.removeSmsDraft('${d['id']}'), child: const Text('Dismiss'))),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= Admin approvals
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<J>> rows;
  final busy = <String>{};

  @override
  void initState() {
    super.initState();
    rows = StoreScope.read(context).adminProfiles();
  }

  Future<void> _set(String id, String status) async {
    setState(() => busy.add(id));
    try {
      await StoreScope.read(context).adminSetStatus(id, status);
      if (!mounted) return;
      toast(context, 'Account ${status == 'approved' ? 'approved' : status}');
      setState(() => rows = StoreScope.read(context).adminProfiles());
    } catch (e) {
      if (mounted) toast(context, 'Could not update account: $e');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registration approvals'), actions: [IconButton(onPressed: () => setState(() => rows = StoreScope.read(context).adminProfiles()), icon: const Icon(Icons.refresh_rounded))]),
      body: FutureBuilder<List<J>>(
        future: rows,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return EmptyNote('Admin dashboard unavailable\n${snap.error}', icon: Icons.error_outline_rounded);
          final L = snap.data ?? const [];
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
            Text('Review new accounts. Only approved accounts can access Salli data.', style: TextStyle(color: p.muted)),
            if (L.isEmpty) const EmptyNote('No other registered users yet.', icon: Icons.people_outline_rounded),
            for (final x in L)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x['full_name'] ?? x['email'] ?? 'No email'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${x['email'] ?? 'No email'}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    if ('${x['phone'] ?? ''}'.isNotEmpty) Text('Phone: ${x['phone']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    if ('${x['country'] ?? ''}'.isNotEmpty) Text('Country: ${x['country']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text('${x['status']} · ${x['created_at'] != null ? fmtDate('${x['created_at']}'.substring(0, 10)) : ''}', style: TextStyle(color: x['status'] == 'approved' ? p.pos : x['status'] == 'pending' ? p.warn : p.neg, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (busy.contains(x['user_id']))
                      const LinearProgressIndicator()
                    else
                      Row(children: [
                        if (x['status'] != 'approved') Expanded(child: FilledButton(onPressed: () => _set('${x['user_id']}', 'approved'), child: const Text('Approve'))),
                        if (x['status'] == 'pending') ...[
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: p.neg), onPressed: () => _set('${x['user_id']}', 'rejected'), child: const Text('Reject'))),
                        ],
                        if (x['status'] == 'approved') Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: p.neg), onPressed: () => _set('${x['user_id']}', 'suspended'), child: const Text('Suspend'))),
                      ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
