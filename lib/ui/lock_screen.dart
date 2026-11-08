import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/round7.dart';
import 'theme.dart';
import 'widgets.dart';

/// Try fingerprint / face unlock. Returns true when it succeeded.
Future<bool> tryBiometric(String reason) async {
  try {
    final la = LocalAuthentication();
    if (!await la.isDeviceSupported()) return false;
    return await la.authenticate(localizedReason: reason, options: const AuthenticationOptions(stickyAuth: true));
  } catch (_) {
    return false;
  }
}

/// PIN pad shown when App Lock is on (same 4-digit PIN as the web app).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String buf = '';
  String err = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    final s = StoreScope.read(context);
    if (s.settings['bio'] != true) return;
    if (await tryBiometric('Unlock Salli')) s.unlock();
  }

  void _key(String k) {
    final s = StoreScope.read(context);
    HapticFeedback.selectionClick();
    setState(() {
      err = '';
      if (k == '⌫') {
        if (buf.isNotEmpty) buf = buf.substring(0, buf.length - 1);
      } else if (buf.length < 4) {
        buf += k;
      }
    });
    if (buf.length == 4) {
      if (s.checkPin(buf)) {
        s.unlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          buf = '';
          err = 'Wrong PIN. Try again.';
        });
      }
    }
  }

  Future<void> _forgot() async {
    final s = StoreScope.read(context);
    final pw = TextEditingController();
    String? e;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Forgot your PIN?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter your Salli account password to turn App Lock off. Your data stays as it is.'),
            const SizedBox(height: 12),
            TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: 'Password', errorText: e)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final email = s.user?.email;
                if (email == null) return;
                try {
                  await s.sb.auth.signInWithPassword(email: email, password: pw.text);
                  s.setPin(null);
                  s.unlock();
                  if (c.mounted) Navigator.pop(c);
                } catch (_) {
                  set(() => e = 'Wrong password, or no internet connection.');
                }
              },
              child: const Text('Turn off lock'),
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
    final bio = s.settings['bio'] == true;
    Widget key(String k) => SizedBox(
          width: 76,
          height: 76,
          child: k.isEmpty
              ? (bio ? IconButton(onPressed: _bio, icon: Icon(Icons.fingerprint_rounded, size: 34, color: p.accent)) : const SizedBox.shrink())
              : TextButton(
                  style: TextButton.styleFrom(shape: const CircleBorder(), backgroundColor: p.card),
                  onPressed: () => _key(k),
                  child: k == '⌫' ? Icon(Icons.backspace_outlined, color: p.fg) : Text(k, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: p.fg)),
                ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 72, height: 72, decoration: BoxDecoration(color: p.accent.withOpacity(.16), shape: BoxShape.circle), child: Icon(Icons.lock_rounded, color: p.accent, size: 34)),
              const SizedBox(height: 16),
              const Text('Enter your PIN', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (bio) Text('or tap the fingerprint to unlock', style: TextStyle(color: p.muted)),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < buf.length ? p.accent : Colors.transparent, border: Border.all(color: p.accent, width: 2)),
                  ),
              ]),
              SizedBox(height: 28, child: Center(child: Text(err, style: TextStyle(color: p.neg)))),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '⌫'],
              ])
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: key(k))])),
              const SizedBox(height: 12),
              TextButton(onPressed: _forgot, child: const Text('Forgot PIN?')),
            ]),
          ),
        ),
      ),
    );
  }
}
