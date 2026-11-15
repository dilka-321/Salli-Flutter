import 'package:flutter/material.dart';

/// Accent colours — same list as the web app (id, label, light tone, dark tone).
const kAccents = <String, (Color, Color)>{
  'emerald': (Color(0xFF1F9D63), Color(0xFF4CC38A)),
  'teal': (Color(0xFF0E8C86), Color(0xFF2EC4B6)),
  'blue': (Color(0xFF2563EB), Color(0xFF5B8DEF)),
  'navy': (Color(0xFF1E3A8A), Color(0xFF7091DD)),
  'indigo': (Color(0xFF4F46E5), Color(0xFF8B85F0)),
  'purple': (Color(0xFF7C3AED), Color(0xFFA78BFA)),
  'rose': (Color(0xFFBE185D), Color(0xFFF27AAE)),
  'amber': (Color(0xFFB45309), Color(0xFFE9B04F)),
  'graphite': (Color(0xFF475569), Color(0xFFA3B1C2)),
};

/// Colours used across the app (true black in dark mode).
class Palette extends ThemeExtension<Palette> {
  final Color bg, card, card2, line, fg, muted, accent, accentInk, pos, neg, warn;

  /// true for the warm frosted-glass look (translucent cards over a soft warm backdrop)
  final bool glass;
  const Palette({
    this.glass = false,
    required this.bg,
    required this.card,
    required this.card2,
    required this.line,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.pos,
    required this.neg,
    required this.warn,
  });

  static Palette of(BuildContext c) => Theme.of(c).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => other is Palette && t > .5 ? other : this;
}

/// Coral accent of the glass look.
const kGlassAccent = Color(0xFFE2553A);

ThemeData buildTheme(Brightness b, String accentId, {bool glass = false}) {
  if (glass) b = Brightness.light;
  final dark = b == Brightness.dark;
  final tones = kAccents[accentId] ?? kAccents['emerald']!;
  final accent = glass ? kGlassAccent : (dark ? tones.$2 : tones.$1);
  final p = glass
      ? const Palette(
          glass: true,
          bg: Color(0xFFF4E6DF),
          card: Color(0xBFFFFFFF),
          card2: Color(0x8CFFFFFF),
          line: Color(0x1F6B3A2C),
          fg: Color(0xFF2A1C18),
          muted: Color(0xFF86675E),
          accent: kGlassAccent,
          accentInk: Colors.white,
          pos: Color(0xFF1E9A60),
          neg: Color(0xFFD23F31),
          warn: Color(0xFFC07300),
        )
      : dark
      ? Palette(
          bg: Colors.black,
          card: const Color(0xFF111214),
          card2: const Color(0xFF1A1B1E),
          line: const Color(0x17FFFFFF),
          fg: const Color(0xFFF2F4F5),
          muted: const Color(0xFF9AA3AB),
          accent: accent,
          accentInk: const Color(0xFF06140D),
          pos: const Color(0xFF4CC38A),
          neg: const Color(0xFFF26B5E),
          warn: const Color(0xFFF2A23C),
        )
      : Palette(
          bg: const Color(0xFFF2F4F6),
          card: Colors.white,
          card2: const Color(0xFFF7F8FA),
          line: const Color(0x14000000),
          fg: const Color(0xFF15191E),
          muted: const Color(0xFF6A747D),
          accent: accent,
          accentInk: Colors.white,
          pos: const Color(0xFF1F9D63),
          neg: const Color(0xFFD9443A),
          warn: const Color(0xFFC77700),
        );
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
    primary: accent,
    onPrimary: p.accentInk,
    surface: p.card,
    onSurface: p.fg,
    error: p.neg,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  const sheet = Color(0xFFFBF2EE);
  return base.copyWith(
    scaffoldBackgroundColor: glass ? Colors.transparent : p.bg,
    canvasColor: glass ? sheet : null,
    dialogTheme: glass ? const DialogThemeData(backgroundColor: sheet, surfaceTintColor: Colors.transparent) : null,
    popupMenuTheme: glass ? const PopupMenuThemeData(color: sheet, surfaceTintColor: Colors.transparent) : null,
    drawerTheme: glass ? const DrawerThemeData(backgroundColor: sheet, surfaceTintColor: Colors.transparent) : null,
    chipTheme: glass ? ChipThemeData(backgroundColor: p.card2, side: BorderSide(color: Colors.white.withOpacity(.7)), shape: const StadiumBorder()) : null,
    extensions: [p],
    textTheme: base.textTheme.apply(bodyColor: p.fg, displayColor: p.fg),
    appBarTheme: AppBarTheme(
      backgroundColor: glass ? Colors.transparent : p.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: p.fg, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    dividerColor: p.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: accent, width: 1.6)),
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: p.accentInk,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.fg,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: accent.withOpacity(.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: glass ? sheet : (dark ? const Color(0xFF0E0E10) : Colors.white),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: glass ? const Color(0xFF3A241E) : (dark ? const Color(0xFF1E2023) : const Color(0xFF15191E)),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    }),
  );
}


/// Soft warm backdrop behind every page in the glass look (blurred-room feel: warm gradient + glowing blobs).
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBD3C7), Color(0xFFF6EAE3), Color(0xFFE6C9BB), Color(0xFFD9B3A2)],
          stops: [0, .35, .7, 1],
        ),
      ),
      child: Stack(children: [
        const Positioned(top: -120, right: -90, child: _Blob(size: 320, color: Color(0x55F08A6C))),
        const Positioned(bottom: 80, left: -120, child: _Blob(size: 340, color: Color(0x40FFFFFF))),
        const Positioned(bottom: -140, right: -60, child: _Blob(size: 300, color: Color(0x40C9785E))),
        Positioned.fill(child: child),
      ]),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0)])),
        ),
      );
}
