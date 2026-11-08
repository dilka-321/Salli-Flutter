import 'package:flutter/material.dart';

import '../config.dart';
import 'categories_screen.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final theme = '${s.settings['theme'] ?? 'system'}';
    final name = '${s.profile?['full_name'] ?? s.settings['name'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        GlassCard(
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: p.accent.withOpacity(.2),
              child: Text(name.isEmpty ? 'S' : name[0].toUpperCase(), style: TextStyle(color: p.accent, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Your profile' : name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${s.user?.email ?? ''}', style: TextStyle(color: p.muted)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Manage'),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: Icon(Icons.category_outlined, color: p.accent),
              title: const Text('Categories'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(pageRoute(const CategoriesScreen())),
            ),
            Divider(height: 1, color: p.line),
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: p.accent),
              title: const Text('Account transfers'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(pageRoute(const TransfersScreen())),
            ),
          ]),
        ),
        const SectionTitle('Appearance'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
            ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
          ],
          selected: {theme},
          onSelectionChanged: (v) => s.setTheme(v.first),
        ),
        const SizedBox(height: 6),
        Text('Accent colour, fonts and the rest of the settings come in a later round. Changes made in the web app apply here too.',
            style: TextStyle(color: p.muted, fontSize: 12.5)),
        const SectionTitle('Cloud sync'),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(s.dirty ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined, color: s.dirty ? p.warn : p.pos),
              const SizedBox(width: 10),
              Expanded(child: Text(s.syncStatus.isEmpty ? 'Synced' : s.syncStatus, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            Text('Your data is the same account as the Salli web app. Changes are saved on this phone first and uploaded when you are online.',
                style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync now'),
              onPressed: () async {
                if (s.dirty) {
                  await s.syncNow();
                } else {
                  await s.pullIfNewer();
                }
                if (context.mounted) toast(context, s.syncStatus.isEmpty ? 'Synced' : s.syncStatus);
              },
            ),
          ]),
        ),
        const SectionTitle('About'),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${AppConfig.appName} native · ${AppConfig.version}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Round 2: sign-in, offline sync, dashboard, accounts, credit cards, transfers with your own exchange rate, categories and transactions. Other sections arrive in the next rounds.',
                style: TextStyle(color: p.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          icon: Icon(Icons.logout_rounded, color: p.neg),
          label: Text('Sign out', style: TextStyle(color: p.neg)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: p.neg.withOpacity(.5))),
          onPressed: () async {
            await s.signOut();
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ]),
    );
  }
}
