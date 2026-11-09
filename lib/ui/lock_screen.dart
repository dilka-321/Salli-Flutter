import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../core/round7.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Root navigator (used to put the lock screen above whatever page is open).
final rootNavKey = GlobalKey<NavigatorState>();

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

/// Branded background used by the lock screen and the app-switcher privacy cover.
class _Brand extends StatelessWidget {
  const _Brand({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(p.accent, Colors.black, .18)!, Color.lerp(p.accent, Colors.black, .55)!]),
      ),
      child: child,
    );
  }
}

class SalliMark extends StatelessWidget {
  const SalliMark({super.key, this.size = 96});
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withOpacity(.95), borderRadius: BorderRadius.circular(size * .28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 24, offset: const Offset(0, 10))]),
        alignment: Alignment.center,
        child: Text('S', style: TextStyle(fontSize: size * .62, fontWeight: FontWeight.w900, color: Color.lerp(p.accent, Colors.black, .25), height: 1)),
      ),
      SizedBox(height: size * .22),
      Text('Salli', style: TextStyle(color: Colors.white, fontSize: size * .3, fontWeight: FontWeight.w800, letterSpacing: .5)),
    ]);
  }
}

/// Shown while the app is in the background / app switcher, so your details stay private.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});
  @override
  Widget build(BuildContext context) => const IgnorePointer(child: _Brand(child: Center(child: SalliMark(size: 110))));
}

/// Puts the lock screen above the open page when App Lock asks for it, and removes it after unlocking — your place is kept.
class LockGuard extends StatefulWidget {
  const LockGuard({super.key, required this.child});
  final Widget child;
  @override
  State<LockGuard> createState() => _LockGuardState();
}

class _LockGuardState extends State<LockGuard> {
  Route<void>? _route;

  void _sync(bool lock) {
    final nav = rootNavKey.currentState;
    if (nav == null) return;
    if (lock && _route == null) {
      _route = PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const LockScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      );
      nav.push(_route!);
      setState(() {});
    } else if (!lock && _route != null) {
      final r = _route!;
      _route = null;
      if (r.isActive) nav.removeRoute(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final lock = s.needsUnlock;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(lock);
    });
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      // while hidden in the app switcher, and for the moment before the lock screen opens
      if (s.phase == Phase.ready && (s.obscured || lock) && _route == null) const Positioned.fill(child: PrivacyCover()),
    ]);
  }
}

/// After the keyboard closes, redraws the open page once (some phones left part of the page blank).
class KeyboardRefresher extends StatefulWidget {
  const KeyboardRefresher({super.key, required this.child});
  final Widget child;
  @override
  State<KeyboardRefresher> createState() => _KeyboardRefresherState();
}

class _KeyboardRefresherState extends State<KeyboardRefresher> with WidgetsBindingObserver {
  double _last = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _t?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final b = views.first.viewInsets.bottom;
    if (_last > 0 && b == 0) {
      _t?.cancel();
      _t = Timer(const Duration(milliseconds: 320), _refresh);
    }
    _last = b;
  }

  void _refresh() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
    WidgetsBinding.instance.scheduleForcedFrame();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Lock screen: Salli cover with fingerprint / face unlock, or the 4-digit PIN (same PIN as the web app).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String buf = '';
  String err = '';
  bool pad = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = StoreScope.read(context);
      if (s.settings['bio'] == true) {
        _bio();
      } else {
        setState(() => pad = true);
      }
    });
  }

  Future<void> _bio() async {
    if (_busy) return;
    _busy = true;
    final s = StoreScope.read(context);
    final ok = await tryBiometric('Unlock Salli');
    _busy = false;
    if (ok) {
      s.unlock();
    } else if (mounted && s.settings['bio'] != true) {
      setState(() => pad = true);
    }
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
                  if (c.mounted) Navigator.pop(c);
                  s.setPin(null);
                  s.unlock();
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
    final bio = s.settings['bio'] == true;
    const white = Colors.white;
    Widget key(String k) => SizedBox(
          width: 72,
          height: 72,
          child: k.isEmpty
              ? (bio ? IconButton(onPressed: _bio, icon: const Icon(Icons.fingerprint_rounded, size: 34, color: white)) : const SizedBox.shrink())
              : TextButton(
                  style: TextButton.styleFrom(shape: const CircleBorder(), backgroundColor: white.withOpacity(.14)),
                  onPressed: () => _key(k),
                  child: k == '⌫' ? const Icon(Icons.backspace_outlined, color: white) : Text(k, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: white)),
                ),
        );
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _Brand(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (c, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const SizedBox(height: 10),
                    SalliMark(size: pad ? 74 : 104),
                    if (pad)
                      Column(children: [
                        const Text('Enter your PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: white)),
                        const SizedBox(height: 14),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 4; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 15,
                              height: 15,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: i < buf.length ? white : Colors.transparent, border: Border.all(color: white, width: 2)),
                            ),
                        ]),
                        SizedBox(height: 26, child: Center(child: Text(err, style: const TextStyle(color: Color(0xFFFFD2D0), fontWeight: FontWeight.w600)))),
                        for (final row in const [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['', '0', '⌫'],
                        ])
                          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: key(k))])),
                        TextButton(onPressed: _forgot, child: const Text('Forgot PIN?', style: TextStyle(color: white))),
                      ])
                    else
                      const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      child: Column(children: [
                        if (bio)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: white.withOpacity(.92), foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                              onPressed: _bio,
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: const Text('Unlock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        if (bio && !pad) TextButton(onPressed: () => setState(() => pad = true), child: const Text('Use PIN', style: TextStyle(color: white))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
