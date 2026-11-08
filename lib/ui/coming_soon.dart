import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.icon, required this.round});
  final String title;
  final IconData icon;
  final String round;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 120), children: [
        GlassCard(
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(color: p.accent.withOpacity(.14), shape: BoxShape.circle),
              child: Icon(icon, color: p.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text('$title is coming in $round', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('This native version is being rebuilt screen by screen. Until this part is ready, use the Salli web app — '
                'both apps share the same account and data, so everything you add in either one shows up in both.',
                textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
            const SizedBox(height: 10),
          ]),
        ),
      ]),
    );
  }
}
