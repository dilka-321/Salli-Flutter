import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'core/store.dart';
import 'ui/auth_screens.dart';
import 'ui/lock_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseKey);
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  runApp(SalliApp(store: store));
  store.start();
}

class SalliApp extends StatelessWidget {
  const SalliApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: Builder(builder: (context) {
        final s = StoreScope.of(context);
        final set = s.data['settings'];
        final themeName = set is Map ? '${set['theme'] ?? 'system'}' : 'system';
        final acc = set is Map ? set['accent'] : null;
        final accentId = acc is Map ? '${acc['id'] ?? 'emerald'}' : (acc is String ? acc : 'emerald');
        final mode = themeName == 'dark' ? ThemeMode.dark : themeName == 'light' ? ThemeMode.light : ThemeMode.system;
        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavKey,
          themeMode: mode,
          theme: buildTheme(Brightness.light, accentId),
          darkTheme: buildTheme(Brightness.dark, accentId),
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(MediaQuery.of(context).textScaler.scale(14) / 14 * _fontScale(set))),
                // lock screen / privacy cover sit above every open page, so your place is kept underneath
                child: _NavBarSafe(child: KeyboardRefresher(child: LockGuard(child: child ?? const SizedBox.shrink()))),
              ),
            );
          },
          home: const _Root(),
        );
      }),
    );
  }
}

/// Phone navigation bar:
/// - 3-button bar → every page (and bottom sheet) stops above the buttons, so nothing hides under them;
/// - swipe gestures → pages stay full screen (drawn edge to edge).
class _NavBarSafe extends StatelessWidget {
  const _NavBarSafe({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final buttons = MediaQuery.viewPaddingOf(context).bottom >= 32; // button bar ≈ 48dp, gesture handle ≈ 0–24dp
    if (!buttons) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, left: false, right: false, child: child),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final Widget page;
    switch (s.phase) {
      case Phase.loading:
        page = const _Splash();
      case Phase.signedOut:
        page = const SignInScreen();
      case Phase.pending:
      case Phase.rejected:
      case Phase.error:
        page = StatusScreen(phase: s.phase);
      case Phase.needsProfile:
        page = const ProfileSetupScreen();
      case Phase.conflict:
        page = const ConflictScreen();
      case Phase.ready:
        page = const Shell();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
      child: KeyedSubtree(key: ValueKey(s.phase), child: page),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.accent, Color.lerp(p.accent, Colors.black, .45)!]),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Salli', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            SizedBox(height: 18),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6)),
          ]),
        ),
      ),
    );
  }
}

double _fontScale(dynamic set) {
  final f = set is Map ? set['font'] : null;
  final v = f is Map ? double.tryParse('${f['scale']}') : null;
  return v == null || v <= 0 ? 1.0 : v.clamp(.8, 1.4).toDouble();
}
