import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../core/currency.dart';
import '../core/export.dart';
import '../core/round7.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import 'files.dart';
import 'lock_screen.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

String fmtDT(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return 'Never';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${fmtDate(isoDate(d))}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

Widget _sec(Palette p, String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(t, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 15)));

Widget _row(BuildContext c, IconData i, String t, String sub, VoidCallback? onTap, {Widget? trailing, Color? color}) {
  final p = Palette.of(c);
  return ListTile(
    leading: Icon(i, color: color ?? p.accent),
    title: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    subtitle: Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5)),
    trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
    onTap: onTap,
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _lock(BuildContext context, bool on) async {
    final s = StoreScope.read(context);
    if (!on) {
      s.setPin(null);
      return toast(context, 'App lock off');
    }
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Set a 4-digit PIN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(controller: a, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'New PIN')),
                TextField(controller: b, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, decoration: InputDecoration(labelText: 'Repeat PIN', errorText: err)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (!RegExp(r'^\d{4}$').hasMatch(a.text)) return set(() => err = 'Use exactly 4 digits.');
                    if (a.text != b.text) return set(() => err = 'The two PINs don’t match.');
                    s.setPin(a.text);
                    s.unlocked = true;
                    Navigator.pop(c);
                    toast(context, 'App lock on');
                  },
                  child: const Text('Turn on'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _profile(BuildContext context) async {
    final s = StoreScope.read(context);
    final name = TextEditingController(text: '${s.profile?['full_name'] ?? s.settings['name'] ?? ''}');
    final phone = TextEditingController(text: '${s.profile?['phone'] ?? s.settings['phone'] ?? ''}');
    final country = TextEditingController(text: '${s.profile?['country'] ?? s.settings['country'] ?? ''}');
    String? err;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Profile', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const Text('Your personal details are saved to your Salli account.'),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                TextField(enabled: false, controller: TextEditingController(text: s.user?.email ?? ''), decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (optional)')),
                const SizedBox(height: 10),
                TextField(controller: country, decoration: const InputDecoration(labelText: 'Country (optional)')),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Palette.of(c).neg))),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (name.text.trim().length < 2) return set(() => err = 'Please enter your full name (at least 2 characters).');
                    final e = await s.saveProfileDetails(name.text.trim(), phone.text.trim(), country.text.trim());
                    if (e != null) return set(() => err = e);
                    s.settings.addAll({'name': name.text.trim(), 'phone': phone.text.trim(), 'country': country.text.trim()});
                    s.commit();
                    if (c.mounted) Navigator.pop(c);
                    if (context.mounted) toast(context, 'Profile saved');
                  },
                  child: const Text('Save'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _erase(BuildContext context) async {
    final s = StoreScope.read(context);
    final ctl = TextEditingController();
    String? err;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Erase all data?', style: TextStyle(color: Palette.of(c).neg)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This deletes every account, transaction, budget, goal and setting in your Salli account (on all devices). Make a backup first if you might need it.'),
            const SizedBox(height: 12),
            TextField(controller: ctl, decoration: InputDecoration(labelText: 'Type ERASE to confirm', errorText: err)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.of(c).neg),
              onPressed: () {
                if (ctl.text.trim().toUpperCase() != 'ERASE') return set(() => err = 'Type ERASE to confirm.');
                s.eraseAll();
                Navigator.pop(c);
                Navigator.of(context).popUntil((r) => r.isFirst);
                toast(context, 'All data erased');
              },
              child: const Text('Erase'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final theme = '${s.settings['theme'] ?? 'system'}';
    final name = '${s.profile?['full_name'] ?? s.settings['name'] ?? ''}';
    final card = (List<Widget> children) => GlassCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          onTap: () => _profile(context),
          child: Row(children: [
            CircleAvatar(radius: 28, backgroundColor: p.accent.withOpacity(.2), child: Text(name.isEmpty ? 'S' : name[0].toUpperCase(), style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? 'Your profile' : name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), Text(s.user?.email ?? '', style: TextStyle(color: p.muted))])),
            const Icon(Icons.edit_outlined),
          ]),
        ),
        _sec(p, 'Appearance'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
            ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
          ],
          selected: {theme},
          onSelectionChanged: (v) => s.setTheme(v.first),
        ),
        _sec(p, 'Accent Color'),
        GlassCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final e in kAccents.entries)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  s.setAccent(e.key);
                },
                child: Column(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Theme.of(context).brightness == Brightness.dark ? e.value.$2 : e.value.$1, Color.lerp(Theme.of(context).brightness == Brightness.dark ? e.value.$2 : e.value.$1, Colors.black, .25)!]),
                      border: Border.all(color: s.accentId == e.key ? p.fg : Colors.transparent, width: 2.5),
                    ),
                    child: s.accentId == e.key ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 4),
                  Text(e.key[0].toUpperCase() + e.key.substring(1), style: const TextStyle(fontSize: 11)),
                ]),
              ),
          ]),
        ),
        _sec(p, 'Font size'),
        SegmentedButton<double>(
          showSelectedIcon: false,
          segments: [for (final f in kFontSizes) ButtonSegment(value: f.$1, label: Text(f.$2, style: const TextStyle(fontSize: 12)))],
          selected: {kFontSizes.map((f) => f.$1).firstWhere((v) => (v - s.fontScale).abs() < .01, orElse: () => 1.0)},
          onSelectionChanged: (v) => s.setFontScale(v.first),
        ),
        _sec(p, 'Preferences'),
        card([
          _row(context, Icons.payments_outlined, 'Currency Settings', 'Base currency: ${s.base} — ${kCurrencyMap[s.base]?.name ?? ''}', () => Navigator.of(context).push(pageRoute(const CurrencySettingsScreen()))),
          _row(context, Icons.currency_exchange_rounded, 'Exchange Rates', 'View and manage currency exchange rates', () => Navigator.of(context).push(pageRoute(const RatesScreen()))),
          _row(context, Icons.notifications_none_rounded, 'Notification Settings', 'Configure app reminders', () => Navigator.of(context).push(pageRoute(const NotifSettingsScreen()))),
          _row(context, Icons.lock_outline_rounded, 'App Lock', 'Enable PIN lock', null, trailing: Switch(value: s.hasPin, onChanged: (v) => _lock(context, v))),
          Opacity(
            opacity: s.hasPin ? 1 : .55,
            child: _row(
              context,
              Icons.fingerprint_rounded,
              'Biometric Unlock',
              s.hasPin ? 'Unlock with fingerprint or face. Your PIN still works as a backup.' : 'Turn on App Lock first. Your PIN is the backup.',
              null,
              trailing: Switch(
                value: s.settings['bio'] == true,
                onChanged: !s.hasPin
                    ? null
                    : (v) async {
                        if (!v) return s.setBio(false);
                        if (await tryBiometric('Confirm to turn on biometric unlock')) {
                          s.setBio(true);
                        } else if (context.mounted) {
                          toast(context, 'Biometric unlock isn’t available on this phone');
                        }
                      },
              ),
            ),
          ),
        ]),
        _sec(p, 'Manage'),
        card([
          _row(context, Icons.category_outlined, 'Categories', 'Income and expense categories', () => Navigator.of(context).push(pageRoute(const CategoriesScreen()))),
          _row(context, Icons.swap_horiz_rounded, 'Account transfers', 'Transfers between your accounts', () => Navigator.of(context).push(pageRoute(const TransfersScreen()))),
        ]),
        _sec(p, 'Account'),
        card([
          _row(context, Icons.person_outline_rounded, 'Profile', name.isEmpty ? 'Add your details' : name, () => _profile(context)),
          _row(context, Icons.cloud_upload_outlined, 'Backup & Restore', 'Keep a copy of your data', () => Navigator.of(context).push(pageRoute(const BackupScreen()))),
          _row(
            context,
            s.dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
            'Cloud account',
            '${s.user?.email ?? 'Not signed in'} · ${s.syncStatus.isEmpty ? 'Synced' : s.syncStatus}',
            () async {
              if (s.dirty) {
                await s.syncNow();
              } else {
                await s.pullIfNewer();
              }
              if (context.mounted) toast(context, s.syncStatus.isEmpty ? 'Synced' : s.syncStatus);
            },
            trailing: const Icon(Icons.sync_rounded),
          ),
          _row(context, Icons.logout_rounded, 'Sign out', 'Sign out of this Salli account', () async {
            if (await confirmDialog(context, 'Sign out of Salli?', 'Your latest changes are saved on this device and will sync when the connection is available.')) {
              await s.signOut();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          }, color: p.neg),
          _row(context, Icons.delete_forever_outlined, 'Erase Data', 'Delete everything in this account', () => _erase(context), color: p.neg),
        ]),
        const SizedBox(height: 16),
        Text('${AppConfig.appName} native ${AppConfig.version} · Private account with offline support', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

// ======================================================================= Backup & Restore
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<void> _backup(BuildContext context, {bool mail = false}) {
    final s = StoreScope.read(context);
    return deliverFileSheet(
      context,
      title: 'Backup Now',
      subtitle: 'A backup file with all your accounts, transactions, budgets and settings will be created.',
      build: () async => Uint8List.fromList(utf8.encode(s.backupJson())),
      name: s.backupName(),
      mime: 'application/json',
      subject: 'Salli backup — ${slashDate(today())}',
      text: 'Salli money manager backup. To restore: open Salli › Backup & Restore › Restore Data and choose this file.',
      onDone: () => s.markBackup(mail: mail),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final s = StoreScope.read(context);
    String? text;
    try {
      text = await pickTextFile();
    } catch (e) {
      if (context.mounted) toast(context, 'Could not open the file: $e');
      return;
    }
    if (text == null || !context.mounted) return;
    try {
      final (d, at) = s.parseBackup(text);
      if (await confirmDialog(context, 'Replace all data?', 'Restoring the backup${at != null ? ' from ${fmtDT(at)}' : ''} replaces everything currently in your Salli account.')) {
        s.restoreBackup(d);
        if (context.mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          toast(context, 'Data restored successfully');
        }
      }
    } catch (e) {
      if (context.mounted) toast(context, e is String ? e : 'That file isn’t a Salli backup. Choose the .json backup file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final ab = s.autoBk;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent.withOpacity(.14)),
            child: Center(child: CircleAvatar(radius: 42, backgroundColor: p.accent, child: Icon(Icons.cloud_upload_rounded, size: 40, color: p.accentInk))),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Back up your data to a file, or restore it from a backup file.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('Last Backup: ${fmtDT(s.settings['lastBackup']?.toString())}', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        const SizedBox(height: 16),
        FilledButton.icon(icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Backup Now'), onPressed: () => _backup(context)),
        const SizedBox(height: 10),
        OutlinedButton.icon(icon: const Icon(Icons.history_rounded), label: const Text('Restore Data'), onPressed: () => _restore(context)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Export transactions to Excel'),
          onPressed: () => deliverFileSheet(context, title: 'Export to Excel', subtitle: 'All transactions and account balances as an .xlsx file.', build: () async => buildAllTxXlsx(s), name: 'Salli_Transactions_${today()}.xlsx', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ),
        _sec(p, 'Automatic backup'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              title: const Text('Auto backup', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Keeps a backup copy on this phone when you open the app and one is due'),
              value: ab['on'] == true,
              onChanged: (v) {
                ab['on'] = v;
                s.commit();
                if (v) runAutoBackup(context, force: true);
              },
            ),
            if (ab['on'] == true) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, children: [
                  for (final e in kBackupFreq.entries)
                    ChoiceChip(
                      label: Text(e.value.$1),
                      selected: (ab['freq'] ?? 'weekly') == e.key,
                      onSelected: (_) {
                        ab['freq'] = e.key;
                        s.commit();
                      },
                    ),
                ]),
              ),
              SwitchListTile(
                title: const Text('Also send to Gmail', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('When a backup is due, Salli opens the share menu with the backup attached — choose Gmail and tap Send'),
                value: ab['gmail'] == true,
                onChanged: (v) {
                  ab['gmail'] = v;
                  s.commit();
                  if (v) runAutoBackup(context, force: true);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text('Last auto backup: ${fmtDT(ab['last']?.toString())}${ab['gmail'] == true ? ' · Last sent to Gmail: ${fmtDT(ab['lastMail']?.toString())}' : ''}', style: TextStyle(color: p.muted, fontSize: 12)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        Text('Keep your backup file somewhere safe (Gmail, Google Drive or your computer). Backups made here also restore in the Salli web app, and the other way round.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

/// Called when the app opens: keeps an automatic backup copy and offers the Gmail copy when due (same schedule as the web app).
Future<void> runAutoBackup(BuildContext context, {bool force = false}) async {
  final s = StoreScope.read(context);
  final ab = s.autoBk;
  if (ab['on'] != true) return;
  final days = kBackupFreq['${ab['freq'] ?? 'weekly'}']?.$2 ?? 7;
  try {
    if (s.backupDue(ab['last']?.toString(), days) || (force && ab['last'] == null)) {
      await keepAutoBackup(s.backupJson(), s.backupName());
      s.markBackup(auto: true);
    }
  } catch (_) {}
  final snooze = int.tryParse('${ab['snooze'] ?? 0}') ?? 0;
  if (ab['gmail'] == true && s.backupDue(ab['lastMail']?.toString(), days) && DateTime.now().millisecondsSinceEpoch > snooze && context.mounted) {
    await showModalBottomSheet(
      context: context,
      builder: (c) {
        final p = Palette.of(c);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CircleAvatar(radius: 26, backgroundColor: p.accent, child: Icon(Icons.cloud_upload_rounded, color: p.accentInk)),
              const SizedBox(height: 10),
              Text('Your ${kBackupFreq['${ab['freq'] ?? 'weekly'}']?.$1.toLowerCase() ?? 'weekly'} backup is ready', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Send it to your Gmail so it’s safe even if you lose your phone. In the share menu choose Gmail, enter your email and tap Send.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Send backup to Gmail'),
                onPressed: () async {
                  Navigator.pop(c);
                  try {
                    await shareBytes(Uint8List.fromList(utf8.encode(s.backupJson())), s.backupName(), 'application/json', subject: 'Salli backup — ${slashDate(today())}', text: 'Salli money manager backup created ${fmtDT(DateTime.now().toIso8601String())}. To restore: open Salli › Backup & Restore › Restore Data and choose this file.');
                    s.markBackup(mail: true);
                  } catch (_) {}
                },
              ),
              TextButton(
                onPressed: () {
                  ab['snooze'] = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
                  s.commit();
                  Navigator.pop(c);
                },
                child: const Text('Later'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ======================================================================= Currency settings
class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});
  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final mine = s.myCurrencies;
    final L = s.currencyOrder.where((c) => q.isEmpty || c.code.toLowerCase().contains(q) || c.name.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Currency Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          onTap: () async {
            final c = await pickCurrency(context, s.base);
            if (c == null || c == s.base || !context.mounted) return;
            if (await confirmDialog(context, 'Change functional currency?', 'Totals, net worth, reports and budgets will be shown in ${kCurrencyMap[c]?.name ?? c}. Your transactions stay in their own account currencies.')) {
              s.setBaseCurrency(c);
              if (context.mounted) toast(context, 'Currency changed to ${kCurrencyMap[c]?.name ?? c}');
            }
          },
          child: Row(children: [
            Icon(Icons.payments_outlined, color: p.accent),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Functional currency: ${s.base} — ${kCurrencyMap[s.base]?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)), Text('Totals, net worth, reports and budgets are shown in this currency', style: TextStyle(color: p.muted, fontSize: 12.5))])),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Row(children: [const Expanded(child: Text('My currencies', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Text('${mine.length} selected', style: TextStyle(color: p.pos))]),
        ),
        Text('Tick every currency you use. They appear first in currency lists and in Exchange Rates.', style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search currency'), onChanged: (v) => setState(() => q = v.toLowerCase())),
        const SizedBox(height: 8),
        for (final c in L)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: mine.contains(c.code),
            activeColor: p.accent,
            secondary: CircleAvatar(backgroundColor: p.accent.withOpacity(.12), child: Text(c.symbol, style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w800))),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${c.code}${c.code == s.base ? ' · functional currency' : ''} · 1 USD = ${s.rates.rateOf('USD', c.code).toStringAsFixed(4)}'),
            onChanged: (_) {
              if (c.code == s.base && mine.contains(c.code)) return toast(context, 'The functional currency stays in your list');
              s.toggleMyCurrency(c.code);
            },
          ),
      ]),
    );
  }
}

// ======================================================================= Exchange rates
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});
  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  String q = '';

  Future<void> _form(J? r) async {
    final s = StoreScope.read(context);
    var from = '${r?['from'] ?? 'USD'}', to = '${r?['to'] ?? s.base}';
    final ctl = TextEditingController(text: r == null ? '' : '${r['rate']}');
    String? err;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(r != null ? 'Edit Rate' : 'Add Manual Rate'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final x = await pickCurrency(c, from);
                    if (x != null) set(() => from = x);
                  },
                  child: Text('From: $from'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final x = await pickCurrency(c, to);
                    if (x != null) set(() => to = x);
                  },
                  child: Text('To: $to'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: ctl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Rate (1 $from = ? $to)', errorText: err)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(ctl.text.replaceAll(',', '').trim()) ?? 0;
                if (from == to) return set(() => err = 'Choose two different currencies.');
                if (v <= 0) return set(() => err = 'Enter a rate above zero.');
                s.saveRate(r?['id']?.toString(), from, to, v);
                Navigator.pop(c);
                toast(context, 'Rate saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final up = q.toUpperCase();
    final mine = s.myCurrencies;
    final manual = s.manualRates.where((r) => up.isEmpty || '${r['from']}'.contains(up) || '${r['to']}'.contains(up)).toList();
    const first = ['USD', 'MVR', 'LKR', 'EUR'];
    final order = [...first, ...mine.where((c) => !first.contains(c)), ...kCurrencyMap.keys.where((c) => !first.contains(c) && !mine.contains(c))];
    final ref = order.map((c) => kCurrencyMap[c]).whereType<Currency>().where((c) => up.isEmpty || c.code.contains(up) || c.name.toUpperCase().contains(up)).toList();
    final lv = s.liveInfo;
    final isManual = (String c) => s.manualRates.any((r) => (r['from'] == 'USD' && r['to'] == c) || (r['to'] == 'USD' && r['from'] == c));
    return Scaffold(
      appBar: AppBar(title: const Text('Exchange Rates'), actions: [
        IconButton(
          tooltip: 'Update rates now',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () async {
            toast(context, 'Updating rates…');
            final r = await s.refreshLiveRates(force: true);
            if (context.mounted) toast(context, r == 'updated' ? 'Exchange rates updated' : 'Couldn’t reach the rates service. Using the last saved rates.');
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _form(null), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search currency (e.g. USD, LKR)'), onChanged: (v) => setState(() => q = v)),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Text('My currencies', style: TextStyle(fontWeight: FontWeight.w800))), TextButton(onPressed: () => Navigator.of(context).push(pageRoute(const CurrencySettingsScreen())), child: const Text('Edit'))]),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in mine) Chip(label: Text('1 USD = ${s.rates.rateOf('USD', c).toStringAsFixed(4)} $c', style: const TextStyle(fontSize: 12)))]),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text('Your manual rates (${s.manualRates.length})', style: TextStyle(color: p.pos, fontWeight: FontWeight.w800))),
        if (manual.isEmpty) Text('None yet. Tap + to set the rate your bank uses.', style: TextStyle(color: p.muted)),
        for (final r in manual)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined, color: p.pos),
            title: Text('${r['from']} → ${r['to']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Rate: ${toD(r['rate']).toStringAsFixed(4)} • ${r['date'] ?? ''}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _form(r), icon: const Icon(Icons.edit_outlined)),
              IconButton(
                onPressed: () {
                  s.deleteRate('${r['id']}');
                  toast(context, 'Rate deleted');
                },
                icon: Icon(Icons.delete_outline, color: p.neg),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Row(children: [
            Expanded(child: Text('Reference rates · 1 USD =', style: TextStyle(color: p.muted, fontWeight: FontWeight.w800, fontSize: 12.5))),
            Flexible(
              child: Text(
                lv == null ? 'Built-in reference rates' : 'Updated ${lv['date'] == today() ? 'today' : 'on ${fmtDate('${lv['date']}')}'}',
                textAlign: TextAlign.right,
                style: TextStyle(color: lv != null && lv['date'] == today() ? p.pos : p.warn, fontSize: 12),
              ),
            ),
          ]),
        ),
        GlassCard(
          child: Column(children: [
            for (final c in ref)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: c.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: '  ${c.name}', style: TextStyle(color: p.muted, fontSize: 12)),
                      if (mine.contains(c.code)) TextSpan(text: '  mine', style: TextStyle(color: p.pos, fontSize: 11, fontWeight: FontWeight.w700)),
                      if (isManual(c.code)) TextSpan(text: '  manual', style: TextStyle(color: p.warn, fontSize: 11, fontWeight: FontWeight.w700)),
                    ])),
                  ),
                  Text(s.rates.rateOf('USD', c.code).toStringAsFixed(4), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Tap ↻ to download today’s rates. Manual rates always take priority over downloaded rates.', style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

// ======================================================================= Notifications
class NotifSettingsScreen extends StatelessWidget {
  const NotifSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final n = s.notifSettings;
    Widget sw(String k, String t, String sub) => SwitchListTile(
          secondary: Icon(Icons.notifications_none_rounded, color: p.accent),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
          value: n[k] != false,
          onChanged: (v) {
            n[k] = v;
            s.commit();
          },
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            sw('bills', 'Bills & due dates', 'Loan instalments, card payments, money owed and to-dos'),
            sw('budget', 'Budget alerts', 'When a budget reaches 80% and 100%'),
            sw('subs', 'Subscription reminders', 'Before a subscription renews'),
            sw('inst', 'Installment reminders', 'Before each installment is due'),
          ]),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(icon: const Icon(Icons.notifications_none_rounded), label: const Text('View notifications'), onPressed: () => Navigator.of(context).push(pageRoute(const NotificationsScreen()))),
        const SizedBox(height: 8),
        Text('Reminders appear in the app’s notification list (the bell on Home).', style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

typedef NoticeOpener = void Function(BuildContext context, AppNotice n);

/// Set by the shell so this file doesn't need to import every screen.
NoticeOpener? openNotice;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.notifications();
    IconData ic(String i) => switch (i) {
          'sub' => Icons.subscriptions_outlined,
          'budget' => Icons.savings_outlined,
          'inst' => Icons.receipt_long_rounded,
          'bank' => Icons.account_balance_rounded,
          'card' => Icons.credit_card_rounded,
          'hand' => Icons.back_hand_outlined,
          'todo' => Icons.check_box_outlined,
          'repeat' => Icons.repeat_rounded,
          _ => Icons.sms_outlined,
        };
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [IconButton(onPressed: () => Navigator.of(context).push(pageRoute(const NotifSettingsScreen())), icon: const Icon(Icons.settings_outlined))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        if (L.isEmpty) const EmptyNote('You’re all caught up\nReminders for bills, budgets, subscriptions and installments appear here', icon: Icons.notifications_none_rounded),
        for (final n in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassCard(
              onTap: () => openNotice?.call(context, n),
              child: Row(children: [
                Builder(builder: (_) {
                  final c = n.level == 'r' ? p.neg : n.level == 'o' ? p.warn : p.pos;
                  return Container(width: 42, height: 42, decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(12)), child: Icon(ic(n.icon), color: c));
                }),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text(n.sub, style: TextStyle(color: p.muted, fontSize: 12.5))])),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
      ]),
    );
  }
}
