import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'core/store.dart';
import 'ui/auth_screens.dart';
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
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _Root(),
        );
      }),
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
